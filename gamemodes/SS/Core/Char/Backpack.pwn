#include <YSI\y_hooks>


#define MAX_BAG_TYPE (4)


enum E_BAG_TYPE_DATA
{
			bag_name[ITM_MAX_NAME],
ItemType:	bag_itemtype,
			bag_size,
			bag_maxMed,
			bag_maxLarge,
			bag_maxCarry,
Float:		bag_attachOffsetX,
Float:		bag_attachOffsetY,
Float:		bag_attachOffsetZ,
Float:		bag_attachRotX,
Float:		bag_attachRotY,
Float:		bag_attachRotZ,
Float:		bag_attachScaleX,
Float:		bag_attachScaleY,
Float:		bag_attachScaleZ
}


static
			bag_TypeData[MAX_BAG_TYPE][E_BAG_TYPE_DATA],
			bag_TypeTotal;

static
Iterator:	bag_Index<ITM_MAX>,
			bag_ContainerItem		[CNT_MAX],
			bag_ContainerPlayer		[CNT_MAX];

static
			bag_PlayerBagID			[MAX_PLAYERS],
			bag_InventoryOptionID	[MAX_PLAYERS],
bool:		bag_TakingOffBag		[MAX_PLAYERS],
			bag_CurrentBag			[MAX_PLAYERS],
			bag_PickUpTick			[MAX_PLAYERS],
Timer:		bag_PickUpTimer			[MAX_PLAYERS],
Timer:		bag_OtherPlayerEnter	[MAX_PLAYERS],
			bag_LookingInBag		[MAX_PLAYERS];



// Zeroing



hook OnGameModeInit()
{
	for(new i; i < CNT_MAX; i++)
	{
		bag_ContainerPlayer[i] = INVALID_PLAYER_ID;
		bag_ContainerItem[i] = INVALID_ITEM_ID;
	}
}

hook OnPlayerConnect(playerid)
{
	bag_PlayerBagID[playerid] = INVALID_ITEM_ID;
	bag_LookingInBag[playerid] = INVALID_PLAYER_ID;
}


/*==============================================================================

	Core

==============================================================================*/


stock DefineBagType(name[ITM_MAX_NAME], ItemType:itemtype, size, max_med, max_large, max_carry, Float:attachOffsetX, Float:attachOffsetY, Float:attachOffsetZ, Float:attachRotX, Float:attachRotY, Float:attachRotZ, Float:attachScaleX, Float:attachScaleY, Float:attachScaleZ)
{
	if(bag_TypeTotal == MAX_BAG_TYPE)
		return -1;

	bag_TypeData[bag_TypeTotal][bag_name]			= name;
	bag_TypeData[bag_TypeTotal][bag_itemtype]		= itemtype;
	bag_TypeData[bag_TypeTotal][bag_size]			= size;
	bag_TypeData[bag_TypeTotal][bag_maxMed]			= max_med;
	bag_TypeData[bag_TypeTotal][bag_maxLarge]		= max_large;
	bag_TypeData[bag_TypeTotal][bag_maxCarry]		= max_carry;
	bag_TypeData[bag_TypeTotal][bag_attachOffsetX]	= attachOffsetX;
	bag_TypeData[bag_TypeTotal][bag_attachOffsetY]	= attachOffsetY;
	bag_TypeData[bag_TypeTotal][bag_attachOffsetZ]	= attachOffsetZ;
	bag_TypeData[bag_TypeTotal][bag_attachRotX]		= attachRotX;
	bag_TypeData[bag_TypeTotal][bag_attachRotY]		= attachRotY;
	bag_TypeData[bag_TypeTotal][bag_attachRotZ]		= attachRotZ;
	bag_TypeData[bag_TypeTotal][bag_attachScaleX]	= attachScaleX;
	bag_TypeData[bag_TypeTotal][bag_attachScaleY]	= attachScaleY;
	bag_TypeData[bag_TypeTotal][bag_attachScaleZ]	= attachScaleZ;

	return bag_TypeTotal++;
}

stock IsItemTypeBag(ItemType:itemtype)
{
	if(!IsValidItemType(itemtype))
		return 0;

	for(new i; i < bag_TypeTotal; i++)
	{
		if(itemtype == bag_TypeData[i][bag_itemtype])
			return 1;
	}

	return 0;
}

stock GetItemBagType(ItemType:itemtype)
{
	if(!IsValidItemType(itemtype))
		return 0;

	for(new i; i < bag_TypeTotal; i++)
	{
		if(itemtype == bag_TypeData[i][bag_itemtype])
			return i;
	}

	return -1;
}

stock GivePlayerBag(playerid, itemid)
{
	if(!IsValidItem(itemid))
		return 0;

	new containerid = GetItemExtraData(itemid);

	if(!IsValidContainer(containerid))
		return 0;

	new bagtype = GetItemBagType(GetItemType(itemid));

	if(bagtype != -1)
	{
		new colour = GetItemTypeColour(bag_TypeData[bagtype][bag_itemtype]);

		bag_PlayerBagID[playerid] = itemid;

		SetPlayerAttachedObject(playerid, ATTACHSLOT_BAG, GetItemTypeModel(bag_TypeData[bagtype][bag_itemtype]), 1,
			bag_TypeData[bagtype][bag_attachOffsetX],
			bag_TypeData[bagtype][bag_attachOffsetY],
			bag_TypeData[bagtype][bag_attachOffsetZ],
			bag_TypeData[bagtype][bag_attachRotX],
			bag_TypeData[bagtype][bag_attachRotY],
			bag_TypeData[bagtype][bag_attachRotZ],
			bag_TypeData[bagtype][bag_attachScaleX],
			bag_TypeData[bagtype][bag_attachScaleY],
			bag_TypeData[bagtype][bag_attachScaleZ], colour, colour);

		bag_ContainerItem[containerid] = itemid;
		bag_ContainerPlayer[containerid] = playerid;
		RemoveItemFromWorld(itemid);

		return 1;
	}

	return 0;
}

stock RemovePlayerBag(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	if(!IsValidItem(bag_PlayerBagID[playerid]))
		return 0;

	RemovePlayerAttachedObject(playerid, ATTACHSLOT_BAG);
	CreateItemInWorld(bag_PlayerBagID[playerid], 0.0, 0.0, 0.0, .world = GetPlayerVirtualWorld(playerid), .interior = GetPlayerInterior(playerid));

	bag_ContainerPlayer[GetItemExtraData(bag_PlayerBagID[playerid])] = INVALID_PLAYER_ID;
	bag_PlayerBagID[playerid] = INVALID_ITEM_ID;

	return 1;
}

stock DestroyPlayerBag(playerid)
{
	if(!(0 <= playerid < MAX_PLAYERS))
		return 0;

	if(!IsValidItem(bag_PlayerBagID[playerid]))
		return 0;

	new containerid = GetItemExtraData(bag_PlayerBagID[playerid]);

	RemovePlayerAttachedObject(playerid, ATTACHSLOT_BAG);
	DestroyContainer(containerid);
	DestroyItem(bag_PlayerBagID[playerid]);

	bag_ContainerPlayer[containerid] = INVALID_PLAYER_ID;
	bag_PlayerBagID[playerid] = INVALID_ITEM_ID;

	return 1;
}


/*==============================================================================

	Internal Functions and Hooks

==============================================================================*/


public OnItemCreate(itemid)
{
	new bagtype = GetItemBagType(GetItemType(itemid));

	if(bagtype != -1)
	{
		new containerid;

		containerid = CreateContainer(
			bag_TypeData[bagtype][bag_name],
			bag_TypeData[bagtype][bag_size],
			.virtual = 1,
			.max_med = bag_TypeData[bagtype][bag_maxMed],
			.max_large = bag_TypeData[bagtype][bag_maxLarge],
			.max_carry = bag_TypeData[bagtype][bag_maxCarry]);

		bag_ContainerItem[containerid] = itemid;
		bag_ContainerPlayer[containerid] = INVALID_PLAYER_ID;

		SetItemExtraData(itemid, containerid);
		Iter_Add(bag_Index, itemid);
	}

	return CallLocalFunction("bag_OnItemCreate", "d", itemid);
}
#if defined _ALS_OnItemCreate
	#undef OnItemCreate
#else
	#define _ALS_OnItemCreate
#endif
#define OnItemCreate bag_OnItemCreate
forward bag_OnItemCreate(itemid);

public OnItemCreateInWorld(itemid)
{
	if(IsItemTypeBag(GetItemType(itemid)))
	{
		SetButtonText(GetItemButtonID(itemid), "Hold "KEYTEXT_INTERACT" to pick up~n~Press "KEYTEXT_INTERACT" to open");
	}

	return CallLocalFunction("bag_OnItemCreateInWorld", "d", itemid);
}
#if defined _ALS_OnItemCreateInWorld
	#undef OnItemCreateInWorld
#else
	#define _ALS_OnItemCreateInWorld
#endif
#define OnItemCreateInWorld bag_OnItemCreateInWorld
forward bag_OnItemCreateInWorld(itemid);

public OnItemDestroy(itemid)
{
	if(IsItemTypeBag(GetItemType(itemid)))
	{
		new containerid = GetItemExtraData(itemid);

		if(IsValidContainer(containerid))
		{
			bag_ContainerPlayer[containerid] = INVALID_PLAYER_ID;
			bag_ContainerItem[containerid] = INVALID_ITEM_ID;
			DestroyContainer(containerid);
		}

		Iter_Remove(bag_Index, itemid);
	}

	return CallLocalFunction("bag_OnItemDestroy", "d", itemid);
}
#if defined _ALS_OnItemDestroy
	#undef OnItemDestroy
#else
	#define _ALS_OnItemDestroy
#endif
#define OnItemDestroy bag_OnItemDestroy
forward bag_OnItemDestroy(itemid);

public OnPlayerPickUpItem(playerid, itemid)
{
	if(BagInteractionCheck(playerid, itemid))
		return 1;

	return CallLocalFunction("bag_OnPlayerPickUpItem", "dd", playerid, itemid);
}
#if defined _ALS_OnPlayerPickUpItem
	#undef OnPlayerPickUpItem
#else
	#define _ALS_OnPlayerPickUpItem
#endif
#define OnPlayerPickUpItem bag_OnPlayerPickUpItem
forward bag_OnPlayerPickUpItem(playerid, itemid);

public OnPlayerUseItemWithItem(playerid, itemid, withitemid)
{
	if(BagInteractionCheck(playerid, withitemid))
		return 1;

	return CallLocalFunction("bag_OnPlayerUseItemWithItem", "ddd", playerid, itemid, withitemid);
}
#if defined _ALS_OnPlayerUseItemWithItem
	#undef OnPlayerUseItemWithItem
#else
	#define _ALS_OnPlayerUseItemWithItem
#endif
#define OnPlayerUseItemWithItem bag_OnPlayerUseItemWithItem
forward bag_OnPlayerUseItemWithItem(playerid, itemid, withitemid);

public OnPlayerUseWeaponWithItem(playerid, weapon, itemid)
{
	if(BagInteractionCheck(playerid, itemid))
		return 1;

	return CallLocalFunction("bag_OnPlayerUseWeaponWithItem", "ddd", playerid, weapon, itemid);
}
#if defined _ALS_OnPlayerUseWeaponWithItem
	#undef OnPlayerUseWeaponWithItem
#else
	#define _ALS_OnPlayerUseWeaponWithItem
#endif
#define OnPlayerUseWeaponWithItem bag_OnPlayerUseWeaponWithItem
forward bag_OnPlayerUseWeaponWithItem(playerid, weapon, itemid);

BagInteractionCheck(playerid, itemid)
{
	if(IsItemTypeBag(GetItemType(itemid)))
	{
		stop bag_PickUpTimer[playerid];
		bag_PickUpTimer[playerid] = defer bag_PickUp(playerid, itemid);

		bag_PickUpTick[playerid] = GetTickCount();
		bag_CurrentBag[playerid] = itemid;

		return 1;
	}

	return 0;
}

hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_CUFFED || IsPlayerOnAdminDuty(playerid) || IsPlayerKnockedOut(playerid) || GetPlayerAnimationIndex(playerid) == 1381 || GetTickCountDifference(GetTickCount(), GetPlayerWeaponSwapTick(playerid)) < 1000)
		return 1;

	if(IsPlayerInAnyVehicle(playerid))
		return 1;

	if(IsValidItem(bag_PlayerBagID[playerid]))
	{
		if(newkeys & KEY_NO)
		{
			if(!IsValidItem(GetPlayerItem(playerid)) && GetPlayerWeapon(playerid) == 0 && !IsValidItem(GetPlayerInteractingItem(playerid)))
			{
				RemovePlayerAttachedObject(playerid, ATTACHSLOT_BAG);
				CreateItemInWorld(bag_PlayerBagID[playerid], 0.0, 0.0, 0.0, .world = GetPlayerVirtualWorld(playerid), .interior = GetPlayerInterior(playerid));
				GiveWorldItemToPlayer(playerid, bag_PlayerBagID[playerid], 1);
				bag_ContainerPlayer[GetItemExtraData(bag_PlayerBagID[playerid])] = INVALID_PLAYER_ID;
				bag_PlayerBagID[playerid] = INVALID_ITEM_ID;
				bag_TakingOffBag[playerid] = true;
			}
		}
		if(newkeys & KEY_YES)
		{
			if(GetTickCountDifference(GetTickCount(), GetPlayerWeaponSwapTick(playerid)) < 1000)
				return 0;

			new itemid = GetPlayerItem(playerid);

			if(IsPlayerInventoryFull(playerid) || GetItemTypeSize(GetItemType(itemid)) == ITEM_SIZE_MEDIUM)
			{
				new containerid = GetItemExtraData(bag_PlayerBagID[playerid]);

				if(IsValidContainer(containerid) && IsValidItem(itemid))
				{
					if(IsContainerFull(containerid))
					{
						ShowActionText(playerid, "Bag full", 3000, 150);
					}
					else
					{
						ShowActionText(playerid, "Item added to bag", 3000, 150);
						ApplyAnimation(playerid, "PED", "PHONE_IN", 4.0, 1, 0, 0, 0, 300);
						defer bag_PutItemIn(playerid, itemid, containerid);
					}
				}
			}
		}
	}
	else
	{
		if(newkeys & KEY_YES)
		{
			new itemid = GetPlayerItem(playerid);

			if(IsItemTypeBag(GetItemType(itemid)))
				GivePlayerBag(playerid, itemid);
		}
	}

	if(newkeys & 16)
	{
		foreach(new i : Player)
		{
			if(IsPlayerInPlayerArea(playerid, i))
			{
				if(IsValidItem(bag_PlayerBagID[i]))
				{
					new
						Float:px,
						Float:py,
						Float:pz,
						Float:tx,
						Float:ty,
						Float:tz,
						Float:tr,
						Float:angle;

					GetPlayerPos(playerid, px, py, pz);
					GetPlayerPos(i, tx, ty, tz);
					GetPlayerFacingAngle(i, tr);

					angle = absoluteangle(tr - GetAngleToPoint(tx, ty, px, py));

					if(155.0 < angle < 205.0)
					{
						CancelPlayerMovement(playerid);
						bag_OtherPlayerEnter[playerid] = defer bag_EnterOtherPlayer(playerid, i);
						break;
					}
				}
			}
		}
	}

	if(oldkeys & 16)
	{
		stop bag_OtherPlayerEnter[playerid];

		if(GetTickCountDifference(GetTickCount(), bag_PickUpTick[playerid]) < 200)
		{
			if(IsValidItem(bag_CurrentBag[playerid]))
			{
				DisplayContainerInventory(playerid, GetItemExtraData(bag_CurrentBag[playerid]));
				ApplyAnimation(playerid, "BOMBER", "BOM_PLANT_IN", 4.0, 0, 0, 0, 1, 0);
				stop bag_PickUpTimer[playerid];
				bag_PickUpTick[playerid] = 0;
			}
		}
	}

	return 1;
}

timer bag_PickUp[250](playerid, itemid)
{
	if(IsValidItem(GetPlayerItem(playerid)) || GetPlayerWeapon(playerid) != 0)
		return;

	PlayerPickUpItem(playerid, itemid);

	return;
}

timer bag_PutItemIn[300](playerid, itemid, containerid)
{
	AddItemToContainer(containerid, itemid, playerid);
}

timer bag_EnterOtherPlayer[250](playerid, targetid)
{
	CancelPlayerMovement(playerid);
	DisplayContainerInventory(playerid, GetItemExtraData(bag_PlayerBagID[targetid]));
	bag_LookingInBag[playerid] = targetid;
}

PlayerBagUpdate(playerid)
{
	if(IsPlayerConnected(bag_LookingInBag[playerid]))
	{
		if(GetPlayerDist3D(playerid, bag_LookingInBag[playerid]) > 1.0)
		{
			ClosePlayerContainer(playerid);
			CancelSelectTextDraw(playerid);
			bag_LookingInBag[playerid] = -1;
		}
	}
}


public OnPlayerCloseContainer(playerid, containerid)
{
	if(IsValidItem(bag_CurrentBag[playerid]))
	{
		ClearAnimations(playerid);
		bag_CurrentBag[playerid] = INVALID_ITEM_ID;
		bag_LookingInBag[playerid] = -1;
	}

	return CallLocalFunction("bag_OnPlayerCloseContainer", "dd", playerid, containerid);
}
#if defined _ALS_OnPlayerCloseContainer
	#undef OnPlayerCloseContainer
#else
	#define _ALS_OnPlayerCloseContainer
#endif
#define OnPlayerCloseContainer bag_OnPlayerCloseContainer
forward bag_OnPlayerCloseContainer(playerid, containerid);

public OnPlayerUseItem(playerid, itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(IsItemTypeBag(itemtype))
	{
		CancelPlayerMovement(playerid);
		DisplayContainerInventory(playerid, GetItemExtraData(itemid));
	}
	return CallLocalFunction("bag_OnPlayerUseItem", "dd", playerid, itemid);
}
#if defined _ALS_OnPlayerUseItem
	#undef OnPlayerUseItem
#else
	#define _ALS_OnPlayerUseItem
#endif
#define OnPlayerUseItem bag_OnPlayerUseItem
forward bag_OnPlayerUseItem(playerid, itemid);

public OnPlayerDropItem(playerid, itemid)
{
	if(IsItemTypeBag(GetItemType(itemid)))
	{
		if(bag_TakingOffBag[playerid])
		{
			bag_TakingOffBag[playerid] = false;
			return 1;
		}
	}

	return CallLocalFunction("bag_OnPlayerDropItem", "dd", playerid, itemid);
}
#if defined _ALS_OnPlayerDropItem
	#undef OnPlayerDropItem
#else
	#define _ALS_OnPlayerDropItem
#endif
#define OnPlayerDropItem bag_OnPlayerDropItem
forward bag_OnPlayerDropItem(playerid, itemid);

public OnPlayerGiveItem(playerid, targetid, itemid)
{
	if(IsItemTypeBag(GetItemType(itemid)))
	{
		if(bag_TakingOffBag[playerid])
		{
			bag_TakingOffBag[playerid] = false;
			return 1;
		}
	}

	return CallLocalFunction("bag_OnPlayerGiveItem", "ddd", playerid, targetid, itemid);
}
#if defined _ALS_OnPlayerGiveItem
	#undef OnPlayerGiveItem
#else
	#define _ALS_OnPlayerGiveItem
#endif
#define OnPlayerGiveItem bag_OnPlayerGiveItem
forward bag_OnPlayerGiveItem(playerid, targetid, itemid);

public OnPlayerViewInventoryOpt(playerid)
{
	if(IsValidItem(bag_PlayerBagID[playerid]) && !IsValidContainer(GetPlayerCurrentContainer(playerid)))
	{
		bag_InventoryOptionID[playerid] = AddInventoryOption(playerid, "Move to bag");
	}

	return CallLocalFunction("bag_PlayerViewInventoryOpt", "d", playerid);
}
#if defined _ALS_OnPlayerViewInventoryOpt
	#undef OnPlayerViewInventoryOpt
#else
	#define _ALS_OnPlayerViewInventoryOpt
#endif
#define OnPlayerViewInventoryOpt bag_PlayerViewInventoryOpt
forward bag_PlayerViewInventoryOpt(playerid);

public OnPlayerSelectInventoryOpt(playerid, option)
{
	if(IsValidItem(bag_PlayerBagID[playerid]) && !IsValidContainer(GetPlayerCurrentContainer(playerid)))
	{
		if(option == bag_InventoryOptionID[playerid])
		{
			new
				containerid,
				slot,
				itemid;
			
			containerid = GetItemExtraData(bag_PlayerBagID[playerid]);
			slot = GetPlayerSelectedInventorySlot(playerid);
			itemid = GetInventorySlotItem(playerid, slot);

			if(!IsValidItem(itemid))
			{
				DisplayPlayerInventory(playerid);
				return 0;
			}

			if(IsContainerFull(containerid))
			{
				new
					str[CNT_MAX_NAME + 6],
					name[CNT_MAX_NAME];

				GetContainerName(containerid, name);
				format(str, sizeof(str), "%s full", name);
				ShowActionText(playerid, str, 3000, 100);
				DisplayPlayerInventory(playerid);
				return 0;
			}

			RemoveItemFromInventory(playerid, slot, 0);
			AddItemToContainer(containerid, itemid, playerid);
			DisplayPlayerInventory(playerid);
		}
	}

	return CallLocalFunction("bag_PlayerSelectInventoryOption", "dd", playerid, option);
}
#if defined _ALS_OnPlayerSelectInventoryOpt
	#undef OnPlayerSelectInventoryOpt
#else
	#define _ALS_OnPlayerSelectInventoryOpt
#endif
#define OnPlayerSelectInventoryOpt bag_PlayerSelectInventoryOpt
forward bag_PlayerSelectInventoryOpt(playerid, option);

public OnPlayerViewContainerOpt(playerid, containerid)
{
	if(IsValidItem(bag_PlayerBagID[playerid]) && containerid != GetItemExtraData(bag_PlayerBagID[playerid]))
	{
		bag_InventoryOptionID[playerid] = AddContainerOption(playerid, "Move to bag");
	}

	return CallLocalFunction("bag_OnPlayerViewContainerOpt", "dd", playerid, containerid);
}
#if defined _ALS_OnPlayerViewContainerOpt
	#undef OnPlayerViewContainerOpt
#else
	#define _ALS_OnPlayerViewContainerOpt
#endif
#define OnPlayerViewContainerOpt bag_OnPlayerViewContainerOpt
forward bag_OnPlayerViewContainerOpt(playerid, containerid);

public OnPlayerSelectContainerOpt(playerid, containerid, option)
{
	if(IsValidItem(bag_PlayerBagID[playerid]) && containerid != GetItemExtraData(bag_PlayerBagID[playerid]))
	{
		if(option == bag_InventoryOptionID[playerid])
		{
			new
				bagcontainerid,
				slot,
				itemid;

			bagcontainerid = GetItemExtraData(bag_PlayerBagID[playerid]);
			slot = GetPlayerContainerSlot(playerid);
			itemid = GetContainerSlotItem(containerid, slot);

			if(!IsValidItem(itemid))
			{
				DisplayContainerInventory(playerid, containerid);
				return 0;
			}

			if(IsContainerFull(bagcontainerid))
			{
				new
					str[CNT_MAX_NAME + 6],
					name[CNT_MAX_NAME];

				GetContainerName(bagcontainerid, name);
				format(str, sizeof(str), "%s full", name);
				ShowActionText(playerid, str, 3000, 100);
				DisplayContainerInventory(playerid, containerid);
				return 0;
			}

			if(!WillItemTypeFitInContainer(bagcontainerid, GetItemType(itemid)))
			{
				ShowActionText(playerid, "Item won't fit", 3000, 140);
				DisplayContainerInventory(playerid, containerid);
				return 0;
			}

			RemoveItemFromContainer(containerid, slot);
			AddItemToContainer(bagcontainerid, itemid, playerid);
			DisplayContainerInventory(playerid, containerid);
		}
	}

	return CallLocalFunction("bag_OnPlayerSelectContainerOpt", "ddd", playerid, containerid, option);
}
#if defined _ALS_OnPlayerSelectContainerOpt
	#undef OnPlayerSelectContainerOpt
#else
	#define _ALS_OnPlayerSelectContainerOpt
#endif
#define OnPlayerSelectContainerOpt bag_OnPlayerSelectContainerOpt
forward bag_OnPlayerSelectContainerOpt(playerid, containerid, option);


/*==============================================================================

	Interface

==============================================================================*/


stock GetPlayerBagItem(playerid)
{
	if(!(0 <= playerid < MAX_PLAYERS))
		return INVALID_ITEM_ID;

	return bag_PlayerBagID[playerid];
}

stock GetContainerPlayerBag(containerid)
{
	if(!IsValidContainer(containerid))
		return INVALID_PLAYER_ID;

	return bag_ContainerPlayer[containerid];
}

stock GetContainerBagItem(containerid)
{
	if(!IsValidContainer(containerid))
		return INVALID_ITEM_ID;

	return bag_ContainerItem[containerid];
}
