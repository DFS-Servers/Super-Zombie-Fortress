//
// Main.Help Menu
//
public void panel_PrintMain(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Super Zombie Fortress");
	panel.DrawItem(" Overview");
	panel.DrawItem(" Team: Survivors");
	panel.DrawItem(" Team: Infected");
	panel.DrawItem(" Classes: Survivors");
	panel.DrawItem(" Classes: Infected");
	panel.DrawItem(" Classes: Infected (Special)");
	panel.DrawItem(" Daily Mutation");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleHelp, 30);
	CloseHandle_2(panel);
}

public int panel_HandleHelp(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintOverview(param1);
			case 2: panel_PrintTeam(param1, view_as<int>(surTeam()));
			case 3: panel_PrintTeam(param1, view_as<int>(zomTeam()));
			case 4: panel_PrintSurClass(param1);
			case 5: panel_PrintZomClass(param1);
			case 6: panel_PrintZomSpecial(param1);
			case 7: panel_PrintMutations(param1);
			default: return;
		}
	}
}

//
// Main.Help.Overview Menus
//
public void panel_PrintOverview(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Overview");
	panel.DrawText("-------------------------------------------");
	panel.DrawText("Survivors must fulfil the map objective while surviving the Infected.");
	panel.DrawText("When a Survivor dies, they join the Infected.");
	panel.DrawText("Infected need to work together to take down the survivors.");
	panel.DrawText("Survivor gain access to morale and weapon pickups, while Infected gain access to special abilities at times.");
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleOverview, 30);
	CloseHandle_2(panel);
}

public int panel_HandleOverview(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}

//
// Main.Help.Team Menus
//
public void panel_PrintTeam(int iClient, int team)
{
	Panel panel = new Panel();
	if (team == view_as<int>(surTeam()))
	{
		panel.SetTitle("Survivors");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Survivors consist of Soldiers, Pyros, Demoman, Medics, Engineers and Snipers.");
		panel.DrawText("They only start with a melee weapon, you can find weapons in the map.");
		panel.DrawText("They gain additional health regen, damage and other things based on Morale.");
		panel.DrawText("Morale is gained with doing objectives and kills, but lost over time and with negative events occuring.");
		panel.DrawText("-------------------------------------------");
	}
	else if (team == view_as<int>(zomTeam()))
	{
		panel.SetTitle("Infected");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Infected consist of Scouts, Heavies and Spies.");
		panel.DrawText("They are stronger when sticking together and can enrage to boost health (or activate abilities as special infected).");
		panel.DrawText("Enrage is used by using 'CALL MEDIC' and has a cooldown after use.");
		panel.DrawText("Upon killing a survivor, they may be given the option to respawn as a special infected using 'CALL MEDIC'.");
		panel.DrawText("-------------------------------------------");
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleTeam, 30);
	CloseHandle_2(panel);
}

public int panel_HandleTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}


//
// Survivor Classes Selector
//
public void panel_PrintSurClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Survivor Classes");
	panel.DrawItem(" Soldier");
	panel.DrawItem(" Pyro");
	panel.DrawItem(" Demoman");
	panel.DrawItem(" Medic");
	panel.DrawItem(" Engineer");
	panel.DrawItem(" Sniper");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleSurClass, 30);
	CloseHandle_2(panel);
}

public int panel_HandleSurClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Soldier);
			case 2: panel_PrintClass(param1, TFClass_Pyro);
			case 3: panel_PrintClass(param1, TFClass_DemoMan);
			case 4: panel_PrintClass(param1, TFClass_Medic);
			case 5: panel_PrintClass(param1, TFClass_Engineer);
			case 6: panel_PrintClass(param1, TFClass_Sniper);
			case 7: panel_PrintMain(param1);
			default: return;
		}
	}
}


//
// Zombie Classes Selector
//
public void panel_PrintZomClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Zombie Classes");
	panel.DrawItem(" Scout");
	panel.DrawItem(" Heavy");
	panel.DrawItem(" Spy");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleZomClass, 30);
	CloseHandle_2(panel);
}

public int panel_HandleZomClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Scout);
			case 2: panel_PrintClass(param1, TFClass_Heavy);
			case 3: panel_PrintClass(param1, TFClass_Spy);
			case 4: panel_PrintMain(param1);
			default: return;
		}
	}
}


//
// Classes
//
public void panel_PrintClass(int iClient, TFClassType class)
{
	Panel panel = new Panel();
	switch(class)
	{
		case TFClass_Soldier:
		{
			panel.SetTitle("Soldier");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 2 rockets per kill, the amount is not affected by maximum ammo.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Pyro:
		{
			panel.SetTitle("Pyro");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Movement speed lowered to 240 (from 300).");
			panel.DrawText("FLAMETHROWER: Ammo limited to 100.");
			panel.DrawText("AFTERBURN: Burning zombies move faster.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_DemoMan:
		{
			panel.SetTitle("Demoman");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 1 pipe per kill, the amount is not affected by maximum ammo.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Engineer:
		{
			panel.SetTitle("Engineer");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("NO TELEPORTERS: Can only build Sentries and Dispensers.");
			panel.DrawText("SENTRY: decaying and limited ammo, cannot be replenished.");
			panel.DrawText("DISPENSER: Act as walls, higher health but no ammo replenishment.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Medic:
		{
			panel.SetTitle("Medic");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Movement speed lowered to 300 (from 320).");
			panel.DrawText("Healing done on players is less effective.");
			panel.DrawText("Overheal is limited to 125%% but sticks for a longer duration.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Sniper:
		{
			panel.SetTitle("Sniper");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 2 primary ammo per kill, the amount is not affected by maximum ammo.");
			panel.DrawText("SMG: Doesn't have to reload.");
			panel.DrawText("JARATE: Slows down Infected.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Scout:
		{
			panel.SetTitle("Scout");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Always uses the Sandman as regular Infected.");
			panel.DrawText("Movement speed lowered to 330 (from 400).");
			panel.DrawText("SANDMAN: Balls do not stun but emits a toxic gas instead that damages Survivors who stand on it.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Heavy:
		{
			panel.SetTitle("Heavy");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Uses the Fists.");
			panel.DrawText("Blocks fatal attacks, reducing damage to 150.");
			panel.DrawText("Suffers less knockback from attacks.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Spy:
		{
			panel.SetTitle("Spy");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Backstabs put the victim into a 'scared' state, slowing and disabling weapon usage for 5.5 seconds.");
			panel.DrawText("Survivors may become a bit resistant to backstabs, reducing the duration, to ensure game balance.");
			panel.DrawText("-------------------------------------------");
		}
		default:
		{
			panel.SetTitle("Spectator");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Is immune from the Infected.");
			panel.DrawText("Is truly neutral, not siding with any team.");
			panel.DrawText("-------------------------------------------");
		}
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleClass, 30);
	CloseHandle_2(panel);
}

public int panel_HandleClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}


//
// Special Infected
//
public int panel_PrintZomSpecial(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Special Infected");
	panel.DrawItem(" Tank (Heavy)");
	panel.DrawItem(" Boomer (Heavy)");
	panel.DrawItem(" Charger (Heavy)");
	panel.DrawItem(" Kingpin (Scout)");
	panel.DrawItem(" Stalker (Spy)");
	panel.DrawItem(" Hunter (Scout)");
	panel.DrawItem(" Smoker (Spy)");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleZomSpecial, 30);
	CloseHandle_2(panel);
}

public int panel_HandleZomSpecial(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintSpecial(param1, INFECTED_TANK);
			case 2: panel_PrintSpecial(param1, INFECTED_BOOMER);
			case 3: panel_PrintSpecial(param1, INFECTED_CHARGER);
			case 4: panel_PrintSpecial(param1, INFECTED_KINGPIN);
			case 5: panel_PrintSpecial(param1, INFECTED_STALKER);
			case 6: panel_PrintSpecial(param1, INFECTED_HUNTER);
			case 7: panel_PrintSpecial(param1, INFECTED_SMOKER);
			case 8: panel_PrintMain(param1);
			default: return;
		}
	}
}

public void panel_PrintSpecial(int iClient, int class)
{
	Panel panel = new Panel();
	switch(class)
	{
		case INFECTED_TANK:
		{
			panel.SetTitle("Tank");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("As one of the strongest and brutal infected he has the ability to quickly take down an unsuspecting team of survivors.");
			panel.DrawText("- The Tank has a lot of health which he eventually loses after a while.");
			panel.DrawText("- The Tank starts of fast but is slowed down if damaged by the survivors.");
			panel.DrawText("- The Tank spawns if certain conditions are met.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_BOOMER:
		{
			panel.SetTitle("Boomer");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("He is gross, he is dirty and is not afraid to share this with any unlucky survivors.");
			panel.DrawText("- RAGE: Explode, covering survivors close to him in Jarate.");
			panel.DrawText("- PASSIVE: On death you explode as well, but with less effect.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_CHARGER:
		{
			panel.SetTitle("Charger");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("His inner rage and insanity has caused him to lose any care for how he uses his body, as long as he can take somebody with it.");
			panel.DrawText("- RAGE: Charge, disabling a Survivor for a short period.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_KINGPIN:
		{
			panel.SetTitle("Kingpin");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Kingpin is the director of the pack, he makes sure that the Infected give their fullest in taking down the survivors.");
			panel.DrawText("- RAGE: Defense Buff all Infected near you.");
			panel.DrawText("- PASSIVE: Make Infected stronger when standing near them.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_STALKER:
		{
			panel.SetTitle("Stalker");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Stalker is elusive, being able to get close to survivors and back away in the blink of an eye.");
			panel.DrawText("- PASSIVE: You are always cloaked if you are not close to any Survivor.");
			panel.DrawText("- PASSIVE: Your backstabs are stronger.");
			panel.DrawText("- PASSIVE: Cannot use rage.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_HUNTER:
		{
			panel.SetTitle("Hunter");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Hunter is a fast being, being very agile they can be hard to get rid off during combat.");
			panel.DrawText("- RAGE: Perform a swift leap which can pounce enemies when making physical contact while leaping.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_SMOKER:
		{
			panel.SetTitle("Smoker");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Smoker relies on his toxic beam which damages survivors can pulls them towards the Smoker.");
			panel.DrawText("- RAGE: Fire a beam, pulling and damage Survivors.");
			panel.DrawText("- PASSIVE: Cannot use cloak or rage.");
			panel.DrawText("-------------------------------------------");
		}
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleSpecial, 30);
	CloseHandle_2(panel);
}

public int panel_HandleSpecial(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintZomSpecial(param1);
			default: return;
		}
	}
}


//
// Mutation Menu List
//
public void panel_PrintMutations(int iClient)
{
	char strTitle[64];
	Format(strTitle, sizeof(strTitle), "Mutations");
	Panel panel = new Panel();
	panel.SetTitle("Daily Mutation");
	panel.DrawText(g_strMutationTitles[GetActiveMutation()-1]);
	panel.DrawText(g_strMutationDescriptions[GetActiveMutation()-1]);
	panel.DrawText("-------------------------------------------");
	panel.DrawText("Mutation is the name for a set of modified gameplay modes.");
	panel.DrawText("Mutations are enabled by voting (/votemutation), with enough votes, the next round will run that mutation.");
	panel.DrawText("Every day at 0:00 server time, a new daily mutation is selected.");
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, panel_HandleMutations, 30);
	CloseHandle_2(panel);
}

public int panel_HandleMutations(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}