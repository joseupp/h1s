// botloot.gsc - from "h1botusemore 2.0" by botnok/kinaria
// Allows bots to use camos, furniture kits, DLC weapons and reticles.
// Original: https://discord.com/channels/945420505157083208/1193940039743307848/1404853074840912024
// All credit for this script goes to its author.

#include maps\mp\bots\_bots;
#include maps\mp\bots\_bots_loadout;
main()
{
	replacefunc(maps\mp\bots\_bots_loadout::init_bot_camotable, ::init_bot_camotable_stub);
                replacefunc(maps\mp\bots\_bots_loadout::init_bot_weap_statstable, ::init_bot_weap_statstable_stub);
                replacefunc(maps\mp\bots\_bots_loadout::bot_loadout_choose_from_set, ::bot_loadout_choose_from_set_stub);
                replacefunc(maps\mp\bots\_bots_loadout::bot_loadout_class_callback, ::bot_loadout_class_callback_stub);
                replacefunc(maps\mp\bots\_bots_loadout::bot_loadout_valid_choice, ::bot_loadout_valid_choice_stub);
                init_bot_furniturekittable();
                init_bot_reticletable();
}               

init_bot_reticletable()
{
    var_0 = "mp/reticletable.csv"; 
    level.bot_reticletable = [];
    var_1 = 1;  
    
    for(;;)
    {
        var_2 = tablelookupbyrow(var_0, var_1, 1); 
        if(!isdefined(var_2) || var_2 == "")
            break;
        
        if(var_2 != "none") {
            level.bot_reticletable[level.bot_reticletable.size] = var_2;
        }
        var_1++;
    }
}

bot_loadout_choose_reticletable(var_0, var_1, var_2, var_3, var_4)
{
    if(var_0 == "reticletable") {
        if(isdefined(level.bot_reticletable) && level.bot_reticletable.size > 0) {
            var_5 = common_scripts\utility::random(level.bot_reticletable);
            return var_5;
        } 
    } 
    return "none";
}

init_bot_camotable_stub()
{
    var_0 = "mp/botcamotable.csv";
    var_1 = 1;
    var_2 = 8;
    var_3 = 9;
    level.bot_camotable = [];
    var_4 = 0;

    for (;;)
    {
        var_5 = tablelookupbyrow( var_0, var_4, var_1 );

        if ( !isdefined( var_5 ) || var_5 == "" )
            break;

        var_6 = tablelookupbyrow( var_0, var_4, var_2 );

        if ( isdefined( var_6 ) && var_6 != "" )
        {
            var_7 = tablelookupbyrow( var_0, var_4, var_3 );

            if ( var_7 != "" )
            {
                var_8 = strtok( var_7, "| " );

                foreach ( var_10 in var_8 )
                {
                    if ( !isdefined( level.bot_camotable[var_10] ) )
                        level.bot_camotable[var_10] = [];

                    var_11 = level.bot_camotable[var_10].size;
                    level.bot_camotable[var_10][var_11] = var_5;
                }
            }
        }

        var_4++;
    }
}

init_bot_weap_statstable_stub()
{
    var_0 = "mp/botstatstable.csv";
    var_1 = 4;
    var_2 = 57;
    var_3 = 58;
    level.bot_weap_statstable = [];
    level.bot_weap_personality = [];
    var_4 = 1;

    for (;;)
    {
        var_5 = tablelookupbyrow( var_0, var_4, 0 );

        if ( var_5 == "" )
            break;

        var_6 = tablelookupbyrow( var_0, var_4, var_1 );
        var_7 = tablelookupbyrow( var_0, var_4, var_3 );
        var_8 = tablelookupbyrow( var_0, var_4, var_2 );

        if ( var_7 != "" && var_6 != "" && var_8 != "" )
        {
            var_9 = "loadoutPrimary";

            if ( maps\mp\gametypes\_class::isvalidsecondary( var_6 ) )
                var_9 = "loadoutSecondary";
            else if ( !maps\mp\gametypes\_class::isvalidprimary( var_6 ) )
            {
                var_4++;
                continue;
            }

            if ( var_6 != "" && var_8 != "" )
                level.bot_weap_personality[var_6] = var_8;

            if ( !isdefined( level.bot_weap_statstable[var_9] ) )
                level.bot_weap_statstable[var_9] = [];

            var_10 = strtok( var_8, "| " );
            var_11 = strtok( var_7, "| " );

            foreach ( var_13 in var_10 )
            {
                if ( !isdefined( level.bot_weap_statstable[var_9][var_13] ) )
                    level.bot_weap_statstable[var_9][var_13] = [];

                foreach ( var_15 in var_11 )
                {
                    if ( !isdefined( level.bot_weap_statstable[var_9][var_13][var_15] ) )
                        level.bot_weap_statstable[var_9][var_13][var_15] = [];

                    var_16 = level.bot_weap_statstable[var_9][var_13][var_15].size;
                    level.bot_weap_statstable[var_9][var_13][var_15][var_16] = var_6;
                }
            }
        }

        var_4++;
    }
}

init_bot_furniturekittable()
{
    var_0 = "mp/furniturekits.csv";
    var_1 = 1; 
    var_2 = 6; 
    level.bot_furniturekittable = [];
    var_3 = 0;

    for (;;)
    {
        var_4 = tablelookupbyrow(var_0, var_3, var_1);
        if (!isdefined(var_4) || var_4 == "")
            break;

        var_5 = tablelookupbyrow(var_0, var_3, var_2); // Weapon Classes
        if (isdefined(var_5) && var_5 != "")
        {
            var_6 = strtok(var_5, " ");
            foreach (var_8 in var_6)
            {
                if (!isdefined(level.bot_furniturekittable[var_8]))
                    level.bot_furniturekittable[var_8] = [];
                
                var_9 = level.bot_furniturekittable[var_8].size;
                level.bot_furniturekittable[var_8][var_9] = var_4;
            }
        }
        var_3++;
    }
    
level.bot_weaponclass_to_furniturekitclass = [];
level.bot_weaponclass_to_furniturekitclass["rifle"] = "ast";
level.bot_weaponclass_to_furniturekitclass["smg"] = "smg";
level.bot_weaponclass_to_furniturekitclass["spread"] = "sht";
level.bot_weaponclass_to_furniturekitclass["pistol"] = "pst";
level.bot_weaponclass_to_furniturekitclass["mg"] = "lmg";
level.bot_weaponclass_to_furniturekitclass["sniper"] = "snp";
}

bot_loadout_choose_from_furniturekittable(weaponName)
{
    if (weaponName == "none")
        return "none";
    
    if (!issubstr(weaponName, "_mp") && weaponName != "none")
        weaponName += "_mp";

    var_weaponClass = weaponclass(weaponName);
    
    if (!isdefined(level.bot_weaponclass_to_furniturekitclass[var_weaponClass]))
    {
        if (isSubStr(weaponName, "sniper") || isSubStr(weaponName, "snp"))
            var_furnitureClass = "snp";
        else if (isSubStr(weaponName, "smg"))
            var_furnitureClass = "smg";
        else if (isSubStr(weaponName, "shotgun") || isSubStr(weaponName, "sht"))
            var_furnitureClass = "sht";
        else if (isSubStr(weaponName, "pistol") || isSubStr(weaponName, "pst"))
            var_furnitureClass = "pst";
        else if (isSubStr(weaponName, "lmg") || isSubStr(weaponName, "mg"))
            var_furnitureClass = "lmg";
        else
            var_furnitureClass = "ast"; 
    }
    else
    {
        var_furnitureClass = level.bot_weaponclass_to_furniturekitclass[var_weaponClass];
    }
    
    var_availableKits = level.bot_furniturekittable[var_furnitureClass];
    
    if (!isdefined(var_availableKits) || var_availableKits.size == 0)
        return "none";
    
    if (randomint(100) < 50)
    {
        var_selectedKit = var_availableKits[randomint(var_availableKits.size)];
        return var_selectedKit;
    }
    
    return "none";
}

bot_loadout_choose_from_set_stub( var_0, var_1, var_2, var_3, var_4 )
{
    var_5 = "none";
    var_6 = undefined;
    var_7 = 0.0;

    if ( common_scripts\utility::array_contains( var_0, "specialty_null" ) )
        var_5 = "specialty_null";
    else if ( var_3 == "loadoutEquipment" || var_3 == "loadoutOffhand" || issubstr( var_3, "Perk" ) )
        var_5 = "specialty_null";

    if ( var_1 == "classtable_any" )
    {
        if ( !isdefined( self.default_class_chosen ) )
            self.default_class_chosen = common_scripts\utility::random( [ "class1", "class2", "class3", "class4", "class5", "class6" ] );

        var_0 = [ self.default_class_chosen ];
    }

    foreach ( var_9 in var_0 )
    {
        var_10 = undefined;

        if ( getsubstr( var_9, 0, 9 ) == "template_" )
        {
            var_10 = var_9;
            var_11 = level.botloadouttemplates[var_9][var_3];
            var_9 = bot_loadout_choose_from_set( strtok( var_11, "| " ), var_1, var_2, var_3, 1 );

            if ( isdefined( var_10 ) && isdefined( self.chosentemplates[var_10] ) )
                return var_9;
        }

        if ( var_9 == "attachkittable" )
            return bot_loadout_choose_from_attachkittable( var_1, var_2, var_3, self.personality, self.difficulty );

        if ( var_9 == "weap_statstable" )
            return bot_loadout_choose_from_statstable( var_1, var_2, var_3, self.personality, self.difficulty );

        if ( var_9 == "camotable" )
            return bot_loadout_choose_from_camotable( var_1, var_2, var_3, self.personality, self.difficulty );
         if (var_9 == "reticletable")
        {
            if (var_3 == "loadoutPrimaryReticle")
                return bot_loadout_choose_reticletable("reticletable", var_1, var_2, self.personality, self.difficulty);
            else if (var_3 == "loadoutSecondaryReticle")
                return bot_loadout_choose_reticletable("reticletable", var_1, var_2, self.personality, self.difficulty);
            else
                return "none";
        }

        
    if (var_9 == "furniturekittable")
    {
        if (var_3 == "loadoutPrimaryFurnitureKit")
            return bot_loadout_choose_from_furniturekittable(var_2["loadoutPrimary"]);
        else if (var_3 == "loadoutSecondaryFurnitureKit")
            return bot_loadout_choose_from_furniturekittable(var_2["loadoutSecondary"]);
    }
        if (getsubstr(var_9, 0, 5) == "class" && int(getsubstr(var_9, 5, 6)) > 0)
            var_9 = bot_loadout_choose_from_default_class(var_9, var_3);

        if (bot_loadout_valid_choice(var_1, var_2, var_3, var_9))
        {
            var_7 += 1.0;

            if (randomfloat(1.0) <= 1.0 / var_7)
            {
                var_5 = var_9;
                var_6 = var_10;
            }
        }
    }

    if (isdefined(var_6))
        self.chosentemplates[var_6] = 1;

    return var_5;
}

bot_loadout_valid_choice_stub( var_0, var_1, var_2, var_3 )
{
    var_4 = 1;

    switch ( var_2 )
    {
        case "loadoutPrimary":
            var_4 = bot_loadout_item_allowed( "weapon", var_3, undefined );
            var_4 = var_4 && maps\mp\gametypes\_class::isvalidprimary( var_3 );
            var_4 = var_4 && bot_loadout_item_valid_for_rank( var_0, var_3, self botgetdifficulty() );
            break;
        case "loadoutEquipment":
            var_4 = bot_loadout_item_allowed( "perk", var_3, "Lethal" );
            var_4 = var_4 && maps\mp\gametypes\_class::isvalidequipment( var_3 );
            var_4 = var_4 && bot_loadout_item_valid_for_rank( var_0, var_3, self botgetdifficulty() );
            break;
        case "loadoutOffhand":
            var_4 = bot_validate_offhand( var_3, var_2, var_1 );
            var_4 = var_4 && bot_loadout_item_valid_for_rank( var_0, var_3, self botgetdifficulty() );
            break;
        case "loadoutPrimaryAttachKit":
            var_4 = bot_validate_attachkit_for_weapon( var_3, var_1["loadoutPrimary"], self botgetdifficulty() );
            break;
        case "loadoutPrimaryFurnitureKit":
            var_4 = 1;
            break;
        case "loadoutPrimaryReticle":
            var_4 = 1;
            break;
        case "loadoutPrimaryCamo":
            var_4 = !isdefined( self.botloadoutfavoritecamoprimary ) || var_3 == self.botloadoutfavoritecamoprimary;
            var_4 = var_4 && maps\mp\gametypes\_class::isvalidcamo( var_3 );
            break;
        case "loadoutSecondary":
            var_4 = var_3 != var_1["loadoutPrimary"];
            var_4 = var_4 && bot_loadout_item_allowed( "weapon", var_3, undefined );
            var_4 = var_4 && maps\mp\gametypes\_class::isvalidsecondary( var_3, var_1["loadoutPerk2"] == "specialty_twoprimaries" );
            var_4 = var_4 && bot_loadout_item_valid_for_rank( var_0, var_3, self botgetdifficulty() );
            break;
        case "loadoutSecondaryAttachKit":
            var_4 = bot_validate_attachkit_for_weapon( var_3, var_1["loadoutSecondary"], self botgetdifficulty() );
            break;
        case "loadoutSecondaryFurnitureKit":
            var_4 = 1;
            break;
        case "loadoutSecondaryReticle":
            var_4 = 1;
            break;
        case "loadoutSecondaryCamo":
            var_4 = !isdefined( self.botloadoutfavoritecamosecondary ) || var_3 == self.botloadoutfavoritecamosecondary;
            var_4 = var_4 && maps\mp\gametypes\_class::isvalidcamo( var_3 );
            break;
        case "loadoutPerk1":
        case "loadoutPerk2":
        case "loadoutPerk3":
            var_4 = bot_validate_perk( var_3, var_2, var_1 );
            var_4 = var_4 && bot_loadout_item_valid_for_rank( var_0, var_3, self botgetdifficulty() );
            break;
        default:
            break;
    }

    return var_4;
}

bot_loadout_class_callback_stub( var_0 )
{
    while ( !isdefined( level.bot_loadouts_initialized ) )
        wait 0.05;

    while ( !isdefined( self.personality ) )
        wait 0.05;

    var_1 = [];
    var_2 = bot_loadout_get_difficulty();
    self.difficulty = var_2;
    var_3 = self botgetpersonality();

    if ( !isdefined( self.bot_last_loadout_num ) )
        self.bot_cur_loadout_num = 0;

    self.bot_last_loadout_num = self.bot_cur_loadout_num;

    if ( isdefined( self.pers["botLastLoadout"] ) && maps\mp\_utility::is_true( var_0 ) )
        return self.pers["botLastLoadout"];

    var_4 = !isdefined( self.pers["botLastLoadoutDifficulty"] ) || self.pers["botLastLoadoutDifficulty"] == var_2;
    var_5 = !isdefined( self.pers["botLastLoadoutPersonality"] ) || self.pers["botLastLoadoutPersonality"] == var_3;
    var_6 = 0;

    if ( !var_4 || !var_5 )
    {
        self.pers["botLastLoadout"] = undefined;
        self.pers["botCustomClasses"] = undefined;
        self.pers["botLauncherClassIndex"] = undefined;
        var_6 = 1;
    }

    var_7 = !var_6 && bot_allowed_to_try_last_loadout();

    if ( var_7 )
    {
        var_8 = randomfloat( 1.0 ) > 0.1;

        if ( var_8 )
            return self.pers["botLastLoadout"];
    }

    self.bot_pick_new_loadout_next_spawn = undefined;

    if ( !var_6 )
    {
        var_9 = bot_get_stored_launcher_class();
        var_10 = undefined;

        if ( isdefined( self.respawn_with_launcher ) && isdefined( var_9 ) )
        {
            self.respawn_with_launcher = undefined;
            self.bot_pick_new_loadout_next_spawn = 1;
            var_10 = var_9;
        }

        if ( !isdefined( var_10 ) )
        {
            var_11 = bot_get_stored_custom_classes();
            var_12 = 0;

            if ( isdefined( var_9 ) )
            {
                if ( var_11.size < 5 )
                    var_12 = 1;
            }
            else if ( isdefined( self.respawn_with_launcher ) )
                var_12 = 1;
            else if ( var_11.size < 4 )
                var_12 = 1;

            if ( !var_12 )
                var_10 = common_scripts\utility::random( var_11 );
        }

        if ( isdefined( var_10 ) )
        {
            self.bot_cur_loadout_num++;
            self.pers["botLastLoadout"] = var_10;
            return var_10;
        }
    }

    self.bot_loadout_can_pick_acog_for_sniper = randomfloat( 1.0 ) < 0.5;

    if ( var_3 == "cqb" )
        self.bot_loadout_can_pick_silencer = randomfloat( 1.0 ) < 0.5;
    else
        self.bot_loadout_can_pick_silencer = randomfloat( 1.0 ) < 0.25;

    var_13 = undefined;
    var_14 = bot_custom_classes_allowed();

    if ( var_14 )
    {
        var_13 = bot_loadout_pick( var_3, var_2 );
        var_1 = bot_loadout_choose_values( var_13 );

        if ( isdefined( level.bot_funcs["gametype_loadout_modify"] ) )
            var_1 = self [[ level.bot_funcs["gametype_loadout_modify"] ]]( var_1 );

        var_1 = bot_cross_validate_attachkit_and_perk( var_1, var_13 );

        if ( bot_match_rules_invalidate_loadout( var_1 ) )
            var_14 = 0;
    }

    if ( !var_14 )
    {
        var_1 = bot_default_class_random();
        bot_pick_personality_from_weapon( var_1["loadoutPrimary"] );
    }

    var_1["loadoutMelee"] = "none";

    if ( var_1["loadoutPrimary"] == "none" )
    {
        self.bot_fallback_personality = undefined;
        var_1["loadoutPrimary"] = bot_loadout_choose_fallback_primary( var_1 );
        var_1["loadoutPrimaryCamo"] = "none";
        var_1["loadoutPrimaryAttachKit"] = "none";
        var_1["loadoutPrimaryFurnitureKit"] = "none";
        var_1["loadoutPrimaryReticle"] = "none";

        if ( isdefined( self.bot_fallback_personality ) )
        {
            if ( self.bot_fallback_personality == "weapon" )
                bot_pick_personality_from_weapon( var_1["loadoutPrimary"] );
            else
                maps\mp\bots\_bots_util::bot_set_personality( self.bot_fallback_personality );

            var_3 = self.personality;
            self.bot_fallback_personality = undefined;
        }
    }

    var_18 = isdefined( self.respawn_with_launcher );

    if ( var_14 && maps\mp\bots\_bots::bot_israndom() )
    {
        if ( isdefined( var_1["loadoutPrimaryFurnitureKit"] ) && var_1["loadoutPrimaryFurnitureKit"] == "furniturekittable" )
        {
            var_1["loadoutPrimaryFurnitureKit"] = bot_loadout_choose_from_furniturekittable( var_1, var_1["loadoutPrimary"] );
        }
        
        if ( isdefined( var_1["loadoutSecondaryFurnitureKit"] ) && var_1["loadoutSecondaryFurnitureKit"] == "furniturekittable" )
        {
            var_1["loadoutSecondaryFurnitureKit"] = bot_loadout_choose_from_furniturekittable( var_1, var_1["loadoutSecondary"] );
        }
        if ( isdefined( var_1["loadoutPrimaryReticle"] ) && var_1["loadoutPrimaryReticle"] == "furniturekittable" )
        {
            var_1["loadoutPrimaryReticle"] = bot_loadout_choose_reticletable( var_1, var_1["loadoutPrimaryReticle"] );
        }
        
        if ( isdefined( var_1["loadoutPrimaryCamo"] ) && var_1["loadoutPrimaryCamo"] != "none" && !isdefined( self.botloadoutfavoritecamoprimary ) )
            self.botloadoutfavoritecamoprimary = var_1["loadoutPrimaryCamo"];

        if ( isdefined( var_1["loadoutSecondaryCamo"] ) && var_1["loadoutSecondaryCamo"] != "none" && !isdefined( self.botloadoutfavoritecamosecondary ) )
            self.botloadoutfavoritecamosecondary = var_1["loadoutSecondaryCamo"];

        if ( var_18 )
        {
            var_19 = level.bot_respawn_launcher_name[self botgetdifficulty()];

            if ( bot_loadout_item_allowed( "perk", var_19, "Perk_Slot1" ) )
            {
                var_1["loadoutPerk1"] = var_19;
                var_1["loadoutPrimaryAttachKit"] = "none";
                var_1["loadoutPrimaryAttachKit"] = bot_pick_new_loadout_item( var_13["loadoutPrimaryAttachKit"], var_1, "loadoutPrimaryAttachKit", "loadoutPerk1" );
                self.bot_pick_new_loadout_next_spawn = 1;
            }

            self.respawn_with_launcher = undefined;
        }

        if ( var_1["loadoutPerk2"] == "specialty_explosivedamage" )
        {
            if ( randomfloat( 1.0 ) < 0.5 )
            {
                var_20 = common_scripts\utility::array_randomize( [ "loadoutPrimaryAttachKit", "loadoutPerk1" ] );

                for ( var_21 = 0; var_21 < var_20.size; var_21++ )
                {
                    if ( bot_perk_is_explosive( var_1["loadoutPerk1"] ) )
                        continue;

                    if ( var_1["loadoutPrimaryAttachKit"] == "gl" )
                        continue;

                    if ( var_20[var_21] == "loadoutPrimaryAttachKit" )
                    {
                        var_1["loadoutPerk1"] = "specialty_null";
                        var_22 = bot_loadout_choose_from_set( [ "gl" ], "special_attachkit_choice", var_1, "loadoutPrimaryAttachKit" );

                        if ( var_22 != "none" )
                            var_1["loadoutPrimaryAttachKit"] = var_22;
                    }
                    else if ( var_20[var_21] == "loadoutPerk1" )
                    {
                        var_1["loadoutPrimaryAttachKit"] = "none";
                        var_23 = bot_perk_get_explosive_list();

                        if ( var_3 != "camper" )
                            var_23 = common_scripts\utility::array_remove( var_23, "c4_mp" );

                        var_24 = bot_loadout_choose_from_set( var_23, "special_perk_choice", var_1, "loadoutPerk1" );

                        if ( var_24 != "specialty_null" )
                            var_1["loadoutPerk1"] = var_24;
                    }

                    var_25 = var_20[var_21];
                    var_26 = var_20[( var_21 + 1 ) % 2];
                    var_1[var_26] = bot_pick_new_loadout_item( var_13[var_26], var_1, var_26, var_25 );
                }
            }
        }
    }

    self.bot_cur_loadout_num++;
    self.pers["botLastLoadout"] = var_1;
    self.pers["botLastLoadoutDifficulty"] = var_2;
    self.pers["botLastLoadoutPersonality"] = var_3;

    if ( !isdefined( self.pers["botCustomClasses"] ) )
        self.pers["botCustomClasses"] = [];

    var_27 = self.pers["botCustomClasses"].size;
    self.pers["botCustomClasses"][var_27] = var_1;

    if ( var_18 )
        self.pers["botLauncherClassIndex"] = var_27;

    return var_1;
}