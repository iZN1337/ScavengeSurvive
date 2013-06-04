#include <YSI\y_hooks>


hook OnPlayerConnect(playerid)
{
	SetPlayerColor(playerid, 0xB8B8B800);
	SetPlayerWeather(playerid, gWeatherID);
	GetPlayerName(playerid, gPlayerName[playerid], MAX_PLAYER_NAME);

	if(IsPlayerNPC(playerid))
		return 1;

	tick_ServerJoin[playerid] = tickcount();

	new
		adminlevel,
		ipstring[16],
		ipbyte[4],
		query[128],
		DBResult:result,
		numrows;

	GetPlayerIp(playerid, ipstring, 16);

	sscanf(ipstring, "p<.>a<d>[4]", ipbyte);
	gPlayerData[playerid][ply_IP] = ((ipbyte[0] << 24) | (ipbyte[1] << 16) | (ipbyte[2] << 8) | ipbyte[3]);

	format(query, sizeof(query), "SELECT * FROM `Bans` WHERE `"#ROW_NAME"` = '%s' OR `"#ROW_IPV4"` = '%d'",
		strtolower(gPlayerName[playerid]), gPlayerData[playerid][ply_IP]);

	result = db_query(gAccounts, query);
	numrows = db_num_rows(result);

	if(numrows > 0)
	{
		new
			str[256],
			tmptime[12],
			tm<timestamp>,
			timestampstr[64],
			reason[64];

		db_get_field(result, 2, tmptime, 12);
		db_get_field(result, 3, reason, 64);
		db_free_result(result);
		
		localtime(Time:strval(tmptime), timestamp);
		strftime(timestampstr, 64, "%A %b %d %Y at %X", timestamp);

		format(str, 256, "\
			"#C_YELLOW"Date:\n\t\t"#C_BLUE"%s\n\n\n\
			"#C_YELLOW"Reason:\n\t\t"#C_BLUE"%s", timestampstr, reason);

		ShowPlayerDialog(playerid, d_NULL, DIALOG_STYLE_MSGBOX, "Banned", str, "Close", "");

		format(query, sizeof(query), "UPDATE `Bans` SET `"#ROW_IPV4"` = '%d' WHERE `"#ROW_NAME"` = '%s'",
			gPlayerData[playerid][ply_IP], strtolower(gPlayerName[playerid]));

		db_free_result(db_query(gAccounts, query));

		defer KickPlayerDelay(playerid);

		return 1;
	}
	db_free_result(result);

	format(query, sizeof(query), "SELECT * FROM `Whitelist` WHERE `"#ROW_NAME"` = '%s'", gPlayerName[playerid]);
	result = db_query(gAccounts, query);
	numrows = db_num_rows(result);
	db_free_result(result);

	if(numrows == 0)
	{
		ShowPlayerDialog(playerid, d_NULL, DIALOG_STYLE_MSGBOX, "Whitelist",
			""#C_YELLOW"You are not on the whitelist for this server.\n\
			This is in force to provide the best gameplay experience for all players.\n\n\
			"#C_WHITE"Please apply on "#C_BLUE"Empire-Bay.com"#C_WHITE".\n\
			Applications are always accepted as soon as possible\n\
			There are no requirements, just follow the rules.\n\
			Failure to do so will result in permanent removal from the whitelist.", "Close", "");

		defer KickPlayerDelay(playerid);

		return 1;
	}

	for(new i; i < gTotalAdmins; i++)
	{
		if(!strcmp(gPlayerName[playerid], gAdminData[i][admin_Name]))
		{
			adminlevel = gAdminData[i][admin_Level];
			if(adminlevel > 3) adminlevel = 3;
			break;
		}
	}

	format(query, sizeof(query), "SELECT * FROM `Player` WHERE `"#ROW_NAME"` = '%s'", gPlayerName[playerid]);
	result = db_query(gAccounts, query);

	ResetVariables(playerid);

	if(db_num_rows(result) >= 1)
	{
		new
			tmpField[50],
			dbIP;

		db_get_field_assoc(result, #ROW_PASS, gPlayerData[playerid][ply_Password], MAX_PASSWORD_LEN);

		db_get_field_assoc(result, #ROW_GEND, tmpField, 2);

		if(strval(tmpField) == 0)
		{
			f:bPlayerGameSettings[playerid]<Gender>;
		}
		else
		{
			t:bPlayerGameSettings[playerid]<Gender>;
		}

		db_get_field_assoc(result, #ROW_IPV4, tmpField, 12);
		dbIP = strval(tmpField);

		db_get_field_assoc(result, #ROW_ALIVE, tmpField, 2);

		if(tmpField[0] == '1')
			t:bPlayerGameSettings[playerid]<Alive>;

		else
			f:bPlayerGameSettings[playerid]<Alive>;

		db_get_field_assoc(result, #ROW_SPAWN, tmpField, 50);
		sscanf(tmpField, "ffff",
			gPlayerData[playerid][ply_posX],
			gPlayerData[playerid][ply_posY],
			gPlayerData[playerid][ply_posZ],
			gPlayerData[playerid][ply_rotZ]);

		db_get_field_assoc(result, #ROW_ISVIP, tmpField, 2);

		if(tmpField[0] == '1')
			t:bPlayerGameSettings[playerid]<IsVip>;

		else
			f:bPlayerGameSettings[playerid]<IsVip>;

		t:bPlayerGameSettings[playerid]<HasAccount>;

		if(gPlayerData[playerid][ply_IP] == dbIP)
			Login(playerid);

		else
			DisplayLoginPrompt(playerid);

		f:bPlayerGameSettings[playerid]<IsNewPlayer>;
	}
	else
	{
		new str[150];
		format(str, 150, ""#C_WHITE"Hello %P"#C_WHITE", You must be new here!\nPlease create an account by entering a "#C_BLUE"password"#C_WHITE" below:", playerid);
		ShowPlayerDialog(playerid, d_Register, DIALOG_STYLE_PASSWORD, "Register For A New Account", str, "Accept", "Leave");

		t:bPlayerGameSettings[playerid]<IsNewPlayer>;
	}
	if(bServerGlobalSettings & ServerLocked)
	{
		Msg(playerid, RED, " >  Server Locked by an admin "#C_WHITE"- Please try again soon.");
		MsgAdminsF(1, RED, " >  %s attempted to join the server while it was locked.", gPlayerName[playerid]);
		KickPlayer(playerid, "Joining server while locked");
		return 0;
	}

	MsgAllF(WHITE, " >  %P (%d)"#C_WHITE" has joined", playerid, playerid);

	CheckForExtraAccounts(playerid, gPlayerName[playerid]);

	SetAllWeaponSkills(playerid, 500);
	LoadPlayerTextDraws(playerid);
	SetPlayerScore(playerid, 0);
	Streamer_ToggleIdleUpdate(playerid, true);


	db_free_result(result);

	file_Open(SETTINGS_FILE);
	file_IncVal("Connections", 1);
	file_Save(SETTINGS_FILE);
	file_Close();

	t:bPlayerGameSettings[playerid]<HelpTips>;
	t:bPlayerGameSettings[playerid]<ShowHUD>;

	SetSpawn(playerid, -907.5452, 272.7235, 1014.1449, 0.0);
	SpawnPlayer(playerid);

	MsgF(playerid, YELLOW, " >  MoTD: "#C_BLUE"%s", gMessageOfTheDay);


	if(gPingLimit == 600)
	{
		if(Iter_Count(Player) >= 10)
			gPingLimit = 400;
	}
	else if(gPingLimit == 400)
	{
		if(Iter_Count(Player) < 10)
			gPingLimit = 600;
	}

	return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
	if(bServerGlobalSettings & Restarting)
		return 0;

	if(bPlayerGameSettings[playerid] & LoggedIn && !(bPlayerGameSettings[playerid] & AdminDuty))
	{
		Logout(playerid);
	}

	ResetVariables(playerid);
	UnloadPlayerTextDraws(playerid);

	switch(reason)
	{
		case 0:
			MsgAllF(GREY, " >  %p lost connection.", playerid);

		case 1:
			MsgAllF(GREY, " >  %p left the server.", playerid);
	}

	return 1;
}

ResetVariables(playerid)
{
	bPlayerGameSettings[playerid]		= 0;

	gPlayerData[playerid][ply_Admin]	= 0,
	gPlayerData[playerid][ply_Skin]		= 0,
	gPlayerHP[playerid]					= 100.0;
	gPlayerAP[playerid]					= 0.0;
	gPlayerFP[playerid]					= 80.0;
	gPlayerVehicleID[playerid]			= INVALID_VEHICLE_ID,
	gPlayerWarnings[playerid]			= 0;
	gPlayerPassAttempts[playerid]		= 0;

	SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL,			100);
	SetPlayerSkillLevel(playerid, WEAPONSKILL_SAWNOFF_SHOTGUN,	100);
	SetPlayerSkillLevel(playerid, WEAPONSKILL_MICRO_UZI,		100);

	for(new i; i < 10; i++)
		RemovePlayerAttachedObject(playerid, i);
}

ptask PlayerUpdate[100](playerid)
{
	if(gPlayerSpecTarget[playerid] != INVALID_PLAYER_ID)
	{
		UpdateSpectateMode(playerid);
		return;
	}

	if(GetPlayerPing(playerid) > gPingLimit && tickcount() - tick_ServerJoin[playerid] > 10000)
	{
		gPingLimitStrikes[playerid]++;

		if(gPingLimitStrikes[playerid] == 3)
		{
			new str[128];
			format(str, 128, "Having a ping of: %d limit: %d.", GetPlayerPing(playerid), gPingLimit);
			KickPlayer(playerid, str);

			gPingLimitStrikes[playerid] = 0;

			return;
		}
	}

	new
		hour,
		minute,
		weather;

	if(IsPlayerInAnyVehicle(playerid))
	{
		PlayerVehicleUpdate(playerid);
	}
	else
	{
		if(IsValidVehicle(gPlayerVehicleID[playerid]))
		{
			new Float:health;

			GetVehicleHealth(gPlayerVehicleID[playerid], health);

			if(health < 300.0)
				SetVehicleHealth(gPlayerVehicleID[playerid], 299.0);
		}
	}

	if(gScreenBoxFadeLevel[playerid] > 0)
	{
		PlayerTextDrawBoxColor(playerid, ClassBackGround, gScreenBoxFadeLevel[playerid]);
		PlayerTextDrawShow(playerid, ClassBackGround);

		gScreenBoxFadeLevel[playerid] -= 4;

		if(gPlayerHP[playerid] <= 40.0)
		{
			if(gScreenBoxFadeLevel[playerid] <= floatround((40.0 - gPlayerHP[playerid]) * 4.4))
				gScreenBoxFadeLevel[playerid] = 0;
		}
	}
	else
	{
		if(gPlayerHP[playerid] < 40.0)
		{
			if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_PAINKILL))
			{
				PlayerTextDrawHide(playerid, ClassBackGround);

				if(tickcount() - GetPlayerDrugUseTick(playerid, DRUG_TYPE_PAINKILL) > 60000)
					RemoveDrug(playerid, DRUG_TYPE_PAINKILL);
			}
			else if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_ADRENALINE))
			{
				PlayerTextDrawHide(playerid, ClassBackGround);
			}
			else
			{
				PlayerTextDrawBoxColor(playerid, ClassBackGround, floatround((40.0 - gPlayerHP[playerid]) * 4.4));
				PlayerTextDrawShow(playerid, ClassBackGround);
			}
		}
		else
		{
			if(bPlayerGameSettings[playerid] & Spawned)
				PlayerTextDrawHide(playerid, ClassBackGround);
		}
	}

	KnockOutUpdate(playerid);

	gettime(hour, minute);

	if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_LSD))
	{
		hour = 22;
		minute = 3;
		weather = 33;

		if(tickcount() - GetPlayerDrugUseTick(playerid, DRUG_TYPE_LSD) > 300000)
			RemoveDrug(playerid, DRUG_TYPE_LSD);
	}
	else if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_HEROINE))
	{
		hour = 22;
		minute = 30;
		weather = 33;

		if(tickcount() - GetPlayerDrugUseTick(playerid, DRUG_TYPE_HEROINE) > 300000)
			RemoveDrug(playerid, DRUG_TYPE_HEROINE);
	}
	else
	{
		weather = gWeatherID;
	}

	SetPlayerTime(playerid, hour, minute);
	SetPlayerWeather(playerid, weather);

	if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_AIR))
	{
		SetPlayerDrunkLevel(playerid, 100000);

		if(random(100) < 50)
			GivePlayerHP(playerid, -0.5);
	}

	if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_MORPHINE))
	{
		if(tickcount() - GetPlayerDrugUseTick(playerid, DRUG_TYPE_MORPHINE) > 300000 || gPlayerHP[playerid] >= 100.0)
			RemoveDrug(playerid, DRUG_TYPE_MORPHINE);

		SetPlayerDrunkLevel(playerid, 2200);

		if(random(100) < 80)
			GivePlayerHP(playerid, 0.05, .msg = false);
	}

	if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_ADRENALINE))
	{
		if(tickcount() - GetPlayerDrugUseTick(playerid, DRUG_TYPE_ADRENALINE) > 300000 || gPlayerHP[playerid] >= 100.0)
			RemoveDrug(playerid, DRUG_TYPE_ADRENALINE);

		GivePlayerHP(playerid, 0.01, .msg = false);
	}

	if(bPlayerGameSettings[playerid] & Bleeding)
	{
		if(IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_MORPHINE))
		{
			if(random(100) < 30)
				GivePlayerHP(playerid, -0.01);
		}
		else
		{
			if(random(100) < 60)
				GivePlayerHP(playerid, -0.01);
		}

		if(IsPlayerAttachedObjectSlotUsed(playerid, ATTACHSLOT_BLOOD))
		{
			if(frandom(100.0) < gPlayerHP[playerid])
			{
				RemovePlayerAttachedObject(playerid, ATTACHSLOT_BLOOD);
			}
		}
		else
		{
			if(frandom(100.0) < 100 - gPlayerHP[playerid])
			{
				SetPlayerAttachedObject(playerid, ATTACHSLOT_BLOOD, 18706, 1,  0.088999, 0.020000, 0.044999,  0.088999, 0.020000, 0.044999,  1.179000, 1.510999, 0.005000);
			}
		}
	}
	else
	{
		if(IsPlayerAttachedObjectSlotUsed(playerid, ATTACHSLOT_BLOOD))
			RemovePlayerAttachedObject(playerid, ATTACHSLOT_BLOOD);
	}

	if(bPlayerGameSettings[playerid] & Infected)
	{
		if(!IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_MORPHINE) && !IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_ADRENALINE) && !IsPlayerUnderDrugEffect(playerid, DRUG_TYPE_AIR))
		{
			if(GetPlayerDrunkLevel(playerid) == 0)
			{
				if(tickcount() - tick_LastInfectionFX[playerid] > 500 * gPlayerHP[playerid])
				{
					tick_LastInfectionFX[playerid] = tickcount();
					SetPlayerDrunkLevel(playerid, 5000);
				}
			}
			else
			{
				if(tickcount() - tick_LastInfectionFX[playerid] > 100 * (120 - gPlayerHP[playerid]) || 1 < GetPlayerDrunkLevel(playerid) < 2000)
				{
					tick_LastInfectionFX[playerid] = tickcount();
					SetPlayerDrunkLevel(playerid, 0);
				}
			}
		}
	}

	if(GetPlayerCurrentWeapon(playerid) == 0 && GetPlayerWeapon(playerid))
	{
		RemovePlayerWeapon(playerid);
	}

	PlayerBagUpdate(playerid);

	return;
}

hook OnPlayerRequestClass(playerid, classid)
{
	if(IsPlayerNPC(playerid))return 1;

	t:bPlayerGameSettings[playerid]<FirstSpawn>;

	SetSpawn(playerid, -907.5452, 272.7235, 1014.1449, 0.0);

	return 0;
}

hook OnPlayerRequestSpawn(playerid)
{
	if(IsPlayerNPC(playerid))return 1;

	t:bPlayerGameSettings[playerid]<FirstSpawn>;

	SetSpawn(playerid, -907.5452, 272.7235, 1014.1449, 0.0);

	return 1;
}

hook OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	if(clickedid == Text:65535)
	{
		if(bPlayerGameSettings[playerid] & Dying)
		{
			SelectTextDraw(playerid, 0xFFFFFF88);
		}
		else
		{
			ShowWatch(playerid);
		}
	}
	if(clickedid == DeathButton)
	{
		f:bPlayerGameSettings[playerid]<Dying>;
		TogglePlayerSpectating(playerid, false);
		CancelSelectTextDraw(playerid);
		TextDrawHideForPlayer(playerid, DeathText);
		TextDrawHideForPlayer(playerid, DeathButton);
	}
}

hook OnPlayerSpawn(playerid)
{
	if(IsPlayerNPC(playerid))
		return 1;

	tick_Spawn[playerid] = tickcount();

	SetPlayerWeather(playerid, gWeatherID);
	SetPlayerTeam(playerid, 0);
	ResetPlayerMoney(playerid);

	if(bPlayerGameSettings[playerid] & AdminDuty)
	{
		SetPlayerPos(playerid, 0.0, 0.0, 3.0);
		gPlayerHP[playerid] = 100.0;
		return 1;
	}

	if(bPlayerGameSettings[playerid] & Dying)
	{
		TogglePlayerSpectating(playerid, true);

		defer SetDeathCamera(playerid);

		SetPlayerCameraPos(playerid,
			gPlayerDeathPos[playerid][0] - floatsin(-gPlayerDeathPos[playerid][3], degrees),
			gPlayerDeathPos[playerid][1] - floatcos(-gPlayerDeathPos[playerid][3], degrees),
			gPlayerDeathPos[playerid][2]);

		SetPlayerCameraLookAt(playerid, gPlayerDeathPos[playerid][0], gPlayerDeathPos[playerid][1], gPlayerDeathPos[playerid][2]);

		TextDrawShowForPlayer(playerid, DeathText);
		TextDrawShowForPlayer(playerid, DeathButton);
		SelectTextDraw(playerid, 0xFFFFFF88);
		gPlayerHP[playerid] = 1.0;
	}
	else
	{
		gScreenBoxFadeLevel[playerid] = 0;
		PlayerTextDrawBoxColor(playerid, ClassBackGround, 0x000000FF);
		PlayerTextDrawShow(playerid, ClassBackGround);

		if(bPlayerGameSettings[playerid] & Alive)
		{
			if(bPlayerGameSettings[playerid] & LoggedIn)
			{
				FreezePlayer(playerid, 3000);
				PlayerSpawnExistingCharacter(playerid);
				gScreenBoxFadeLevel[playerid] = 255;
			}
			else
			{
				DisplayLoginPrompt(playerid);
			}
		}
		else
		{
			gPlayerHP[playerid] = 100.0;
			gPlayerAP[playerid] = 0.0;
			gPlayerFP[playerid] = 80.0;
			gPlayerFrequency[playerid] = 108.0;
			PlayerCreateNewCharacter(playerid);
		}
	}

	PlayerPlaySound(playerid, 1186, 0.0, 0.0, 0.0);
	PreloadPlayerAnims(playerid);
	SetAllWeaponSkills(playerid, 500);
	Streamer_Update(playerid);

	RemoveAllDrugs(playerid);

	return 1;
}

timer SetDeathCamera[50](playerid)
{
	InterpolateCameraPos(playerid,
		gPlayerDeathPos[playerid][0] - floatsin(-gPlayerDeathPos[playerid][3], degrees),
		gPlayerDeathPos[playerid][1] - floatcos(-gPlayerDeathPos[playerid][3], degrees),
		gPlayerDeathPos[playerid][2] + 1.0,
		gPlayerDeathPos[playerid][0] - floatsin(-gPlayerDeathPos[playerid][3], degrees),
		gPlayerDeathPos[playerid][1] - floatcos(-gPlayerDeathPos[playerid][3], degrees),
		gPlayerDeathPos[playerid][2] + 20.0,
		30000, CAMERA_MOVE);

	InterpolateCameraLookAt(playerid,
		gPlayerDeathPos[playerid][0],
		gPlayerDeathPos[playerid][1],
		gPlayerDeathPos[playerid][2],
		gPlayerDeathPos[playerid][0],
		gPlayerDeathPos[playerid][1],
		gPlayerDeathPos[playerid][2] + 1.0,
		30000, CAMERA_MOVE);
}

hook OnPlayerUpdate(playerid)
{
	if(bPlayerGameSettings[playerid] & Frozen)
		return 0;

	if(IsPlayerInAnyVehicle(playerid))
	{
		static
			str[8],
			Float:vx,
			Float:vy,
			Float:vz;

		GetVehicleVelocity(gPlayerVehicleID[playerid], vx, vy, vz);
		gPlayerVelocity[playerid] = floatsqroot( (vx*vx)+(vy*vy)+(vz*vz) ) * 150.0;
		format(str, 32, "%.0fkm/h", gPlayerVelocity[playerid]);
		PlayerTextDrawSetString(playerid, VehicleSpeedText, str);
	}

	if(bPlayerGameSettings[playerid] & Alive)
	{
		SetPlayerHealth(playerid, gPlayerHP[playerid]);
		SetPlayerArmour(playerid, gPlayerAP[playerid]);
	}
	else
	{
		SetPlayerHealth(playerid, 100.0);		
	}

	return 1;
}

GetPlayerSpawnPos(playerid, &Float:x, &Float:y, &Float:z)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	x = gPlayerData[playerid][ply_posX];
	z = gPlayerData[playerid][ply_posY];
	x = gPlayerData[playerid][ply_posZ];

	return 1;
}



hook OnPlayerStateChange(playerid, newstate, oldstate)
{
	new vehicleid = GetPlayerVehicleID(playerid);

	if(newstate == PLAYER_STATE_DRIVER || newstate == PLAYER_STATE_PASSENGER)
	{
		new model = GetVehicleModel(vehicleid);

		gPlayerVehicleID[playerid] = vehicleid;

		SetVehicleUsed(vehicleid, true);
		SetVehicleOccupied(vehicleid, true);

		PlayerTextDrawSetString(playerid, VehicleNameText, VehicleNames[model-400]);
		PlayerTextDrawShow(playerid, VehicleNameText);
		PlayerTextDrawShow(playerid, VehicleSpeedText);

		if(GetVehicleType(model) != VTYPE_BMX)
		{
			PlayerTextDrawShow(playerid, VehicleFuelText);
			PlayerTextDrawShow(playerid, VehicleDamageText);
			PlayerTextDrawShow(playerid, VehicleEngineText);
			PlayerTextDrawShow(playerid, VehicleDoorsText);
		}
	}
	if(oldstate == PLAYER_STATE_DRIVER || oldstate == PLAYER_STATE_PASSENGER)
	{
		VehicleDoorsState(gPlayerVehicleID[playerid], 0);

		gPlayerVehicleID[playerid] = INVALID_VEHICLE_ID;
		gPlayerVehicleCurHP[playerid] = 0.0;
		SetVehicleOccupied(vehicleid, false);

		PlayerTextDrawHide(playerid, VehicleNameText);
		PlayerTextDrawHide(playerid, VehicleSpeedText);
		PlayerTextDrawHide(playerid, VehicleFuelText);
		PlayerTextDrawHide(playerid, VehicleDamageText);
		PlayerTextDrawHide(playerid, VehicleEngineText);
		PlayerTextDrawHide(playerid, VehicleDoorsText);
	}
	return 1;
}
hook OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	if(bPlayerGameSettings[playerid] & KnockedOut)
	{
		return 0;
	}

	if(ispassenger)
	{
		new driverid = -1;

		foreach(new i : Player)
		{
			if(IsPlayerInVehicle(i, vehicleid))
			{
				if(GetPlayerState(i) == PLAYER_STATE_DRIVER)
				{
					driverid = i;
				}
			}
		}

		if(driverid == -1)
			CancelPlayerMovement(playerid);
	}

	gCurrentVelocity[playerid] = 0.0;

	return 1;
}
hook OnPlayerExitVehicle(playerid, vehicleid)
{
	gCurrentVelocity[playerid] = 0.0;

	tick_ExitVehicle[playerid] = tickcount();

	return 1;
}

hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(bPlayerGameSettings[playerid] & KnockedOut)
		return 0;

	if(!IsPlayerInAnyVehicle(playerid))
	{
		new weaponid = GetPlayerCurrentWeapon(playerid);

		if(weaponid == 34 || weaponid == 35 || weaponid == 43)
		{
			if(newkeys & 128)
			{
				TogglePlayerHeadwear(playerid, false);
			}
			if(oldkeys & 128)
			{
				TogglePlayerHeadwear(playerid, true);
			}
	}
/*
		if(newkeys & KEY_FIRE)
		{
			new iWepState = GetPlayerWeaponState(playerid);

			if((iWepState != WEAPONSTATE_RELOADING && iWepState != WEAPONSTATE_NO_BULLETS))
				OnPlayerShoot(playerid);
		}
*/
	}

	return 1;
}



IsPlayerDead(playerid)
{
	return bPlayerGameSettings[playerid] & Dying;
}

GetPlayerServerJoinTick(playerid)
{
	return tick_ServerJoin[playerid];
}

GetPlayerSpawnTick(playerid)
{
	return tick_Spawn[playerid];
}

GetPlayerVehicleExitTick(playerid)
{
	return tick_ExitVehicle[playerid];
}
