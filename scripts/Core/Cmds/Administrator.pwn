// 4 commands

new gAdminCommandList_Lvl3[] =
{
	"/up - move up (Duty only)\n\
	/ford - move forward (Duty only)\n\
	/goto - teleport to a player (Duty only)\n\
	/get - teleport a player to you (Duty only)\n"
};

ACMD:up[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new
		Float:distance = float(strval(params)),
		Float:x,
		Float:y,
		Float:z;

	GetPlayerPos(playerid, x, y, z);
	SetPlayerPos(playerid, x, y, z + distance);

	return 1;
}

ACMD:ford[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new
		Float:distance = float(strval(params)),
		Float:x,
		Float:y,
		Float:z,
		Float:a;

	GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, a);

	SetPlayerPos(playerid,
		x + (distance * floatsin(-a, degrees)),
		y + (distance * floatcos(-a, degrees)),
		z);

	return 1;
}

ACMD:goto[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new targetid;

	if(sscanf(params, "d", targetid))
	{
		Msg(playerid, YELLOW, " >  Usage: /goto [playerid]");
		return 1;
	}

	if(!IsPlayerConnected(targetid))
	{
		Msg(playerid, RED, " >  Invalid ID");
		return 1;
	}

	TeleportPlayerToPlayer(playerid, targetid);

	return 1;
}

ACMD:get[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new targetid;

	if(sscanf(params, "d", targetid))
	{
		Msg(playerid, YELLOW, " >  Usage: /get [playerid]");
		return 1;
	}

	if(!IsPlayerConnected(targetid))
	{
		Msg(playerid, RED, " >  Invalid ID");
		return 1;
	}

	if(gPlayerData[playerid][ply_Admin] == 1)
	{
		if(GetPlayerDist3D(playerid, targetid) > 50.0)
		{
			Msg(playerid, RED, " >  You cannot teleport someone that far away from you, move closer to them.");
			return 1;
		}
	}

	TeleportPlayerToPlayer(targetid, playerid);

	return 1;
}

TeleportPlayerToPlayer(playerid, targetid)
{
	new
		Float:px,
		Float:py,
		Float:pz,
		Float:ang,
		Float:vx,
		Float:vy,
		Float:vz,
		interior = GetPlayerInterior(targetid);

	if(IsPlayerInAnyVehicle(targetid))
	{
		new vehicleid = GetPlayerVehicleID(targetid);

		GetVehiclePos(vehicleid, px, py, pz);
		GetVehicleZAngle(vehicleid, ang);
		GetVehicleVelocity(vehicleid, vx, vy, vz);
		pz += 2.0;
	}
	else
	{
		GetPlayerPos(targetid, px, py, pz);
		GetPlayerFacingAngle(targetid, ang);
		GetPlayerVelocity(targetid, vx, vy, vz);
		px -= floatsin(-ang, degrees);
		py -= floatcos(-ang, degrees);
	}

	if(IsPlayerInAnyVehicle(playerid))
	{
		new vehicleid = GetPlayerVehicleID(playerid);

		SetVehiclePos(vehicleid, px, py, pz);
		SetVehicleZAngle(vehicleid, ang);
		SetVehicleVelocity(vehicleid, vx, vy, vz);
		LinkVehicleToInterior(vehicleid, interior);
	}
	else
	{
		SetPlayerPos(playerid, px, py, pz);
		SetPlayerFacingAngle(playerid, ang);
		SetPlayerVelocity(playerid, vx, vy, vz);
		SetPlayerInterior(playerid, interior);
	}

	MsgF(targetid, YELLOW, " >  %P"#C_YELLOW" Has teleported to you", playerid);
	MsgF(playerid, YELLOW, " >  You have teleported to %P", targetid);
}

ACMD:deleteaccount[3](playerid, params[])
{
	if(isnull(params))
	{
		Msg(playerid, YELLOW, " >  Usage: /deleteaccount [account user-name]");
		return 1;
	}

	new ret = DeleteAccount(params);

	if(ret)
		Msg(playerid, YELLOW, " >  Account deleted.");

	else
		Msg(playerid, YELLOW, " >  That account does not exist.");

	return 1;	
}

ACMD:deleteitems[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new Float:range;

	sscanf(params, "f", range);

	if(range == 0.0)
	{
		Msg(playerid, YELLOW, " >  Usage: /deleteitems [range]");
		return 1;
	}

	new
		Float:px,
		Float:py,
		Float:pz,
		Float:ix,
		Float:iy,
		Float:iz;

	GetPlayerPos(playerid, px, py, pz);

	foreach(new i : itm_Index)
	{
		GetItemPos(i, ix, iy, iz);

		if(Distance(px, py, pz, ix, iy, iz) < range)
		{
			i = DestroyItem(i);
		}
	}

	return 1;
}

ACMD:deletetents[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new Float:range;

	sscanf(params, "f", range);

	if(range == 0.0)
	{
		Msg(playerid, YELLOW, " >  Usage: /deletetents [range]");
		return 1;
	}

	new
		Float:px,
		Float:py,
		Float:pz,
		Float:ix,
		Float:iy,
		Float:iz;

	GetPlayerPos(playerid, px, py, pz);

	foreach(new i : tnt_Index)
	{
		GetTentPos(i, ix, iy, iz);

		if(Distance(px, py, pz, ix, iy, iz) < range)
		{
			i = DestroyTent(i);
		}
	}

	return 1;
}

ACMD:deletedefences[3](playerid, params[])
{
	if(gPlayerData[playerid][ply_Admin] == 3)
	{
		if(!(bPlayerGameSettings[playerid] & AdminDuty))
			return 6;
	}

	new Float:range;

	sscanf(params, "f", range);

	if(range == 0.0)
	{
		Msg(playerid, YELLOW, " >  Usage: /deletedefences [range]");
		return 1;
	}

	new
		Float:px,
		Float:py,
		Float:pz,
		Float:ix,
		Float:iy,
		Float:iz;

	GetPlayerPos(playerid, px, py, pz);

	foreach(new i : def_Index)
	{
		GetDefencePos(i, ix, iy, iz);

		if(Distance(px, py, pz, ix, iy, iz) < range)
		{
			i = DestroyDefense(i);
		}
	}

	return 1;
}