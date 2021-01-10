/*
  ______ _____   _      _ _         _             _   _       _      _              _
 |___  // ____| | |    (_) |       | |           | \ | |     | |    | |            | |
    / /| (___   | |     _| |_ ___  | |__  _   _  |  \| | __ _| | ___| | _____ _   _| |__
   / /  \___ \  | |    | | __/ _ \ | '_ \| | | | | . ` |/ _` | |/ _ \ |/ / __| | | | '_ \
  / /__ ____) | | |____| | ||  __/ | |_) | |_| | | |\  | (_| | |  __/   <\__ \ |_| | | | |
 /_____|_____/  |______|_|\__\___| |_.__/ \__, | |_| \_|\__,_|_|\___|_|\_\___/\__,_|_| |_|
                                           __/ |
                                          |___/

This plugin aims to give new server owners something to run if they wish to create a zombie server.
My main zombie plugin which I've spent over two years perfecting and refining is not publicly
available to download for obvious reasons, but this plugin will allow you to run a very basic zombie server
to get you started, or learning to create your own plugins. I have tried to describe what all lines
of code do in the best detail I can.

My main zombie server can be found running on the IP address pvp1.zs.naleksuh.com, and it contains
the following features not found here:

* Zombies are chosen before setup ends
* *A lot* of glitch and exploit fixes (sometimes zombies will not be swapped to melee, you can rejoin red after dying with some cleverness, and a few more)
* Time left is visible to players
* Lots of special and bonus rounds, to keep things interesting
* Zombies can doublejump, making dispenser boosting a lot more fair
* Maps do not have dead ends (for instance you will not have a fun time playing cp_5gorge with this plugin)
* Queued algorithm that can pick multiple zombies fairly instead of a single zombie at random
* Bots to allow you to play even when the server is empty
* Occasional fixed server crashes that this plugin may crash
* And so many more things! But it doesn't mean this plugin is *bad*, I've simply created this to allow starting server owners to get started without either
having to learn SourcePawn themselves or giving away years of code
*/
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
// this stuff is usually used in basically every plugin for tf2, and it comes with SourceMod so you don't have to download anything
int setup = false;
int GlobalVerifier;
public void OnPluginStart(){
  HookEvent("teamplay_round_start", teamplay_round_start, EventHookMode_Post);
  HookEvent("post_inventory_application",post_inventory_application,EventHookMode_Post);
  HookEvent("player_death",player_death,EventHookMode_Post);
  HookEvent("player_team", player_team, EventHookMode_Post);
  // "hook" some events. when certain things happen in the game, tf2 will call these events, and this plugin makes use of them
  // to make certain things happen when those events are called.

  RegConsoleCmd("spectate", Removed);
  RegConsoleCmd("autoteam", Removed); // block out spectate and autoteam commands used for exploiting
  RegConsoleCmd("build", Build);
}

public Action Removed(int client, int args){
  return Plugin_Handled;
}

public Action Build(int client, int args){
  char arg[5];
  GetCmdArg(1, arg, sizeof(arg));
  if(StringToInt(arg) == 2){
    return Plugin_Handled;
  }
  return Plugin_Changed;
}

public Action EndSetup(Handle timer, LocalVerifier){
  if(GlobalVerifier == LocalVerifier){ // avoid double timers
   setup = false;
   if(GetClientCount(true) > 1){ // if there is only one person on the server it'll just pick them as zombie meaning blue instantly wins 60 seconds into the round
     PickRandomZombie(); // this is a custom function defined later on line 81
   }
  }
}
public Action MakeRedWin(Handle timer, int LocalVerifier){
  if(GlobalVerifier == LocalVerifier){
    int win = CreateEntityByName("game_round_win");
    SetVariantInt(2);
    AcceptEntityInput(win, "SetTeam");
    AcceptEntityInput(win, "RoundWin");
    DispatchSpawn(win);
  }
}

public void PickRandomZombie(){
  int client = GetRandomInt(1, MaxClients); // pick a random player by slot. sourcemod uses entity ids instead of user ids, so all entitys
  // between 1 and your max player count are reserved for a player slot
  while(!IsClientInGame(client)){ // but there has to be a player in that slot. this while loop while continue running if we *don't*
  // pick someone in that slot
    client = GetRandomInt(1, MaxClients); // where we continue to pick one
  }
  // this code below will only have ran once we have picked a player in that slot
  TF2_ChangeClientTeam(client, TFTeam_Blue);
  TF2_RespawnPlayer(client);
}
public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast){
  setup = true;
  GlobalVerifier = GetGameTickCount(); // used for avoiding double timers. this is used over handles as it allows the most options but with control
  CreateTimer(60.0, EndSetup, GlobalVerifier); // turn off setup 60 seconds from now, effectively making a 60 seconds setup
  CreateTimer(300.0, MakeRedWin, GlobalVerifier);
  for(int client = 1 ; client <= MaxClients ; client++ ){ // this loops through every possible player in the server
    if(IsClientInGame(client)){ // but it's still important to make sure there is a player occupying that slot, incase the server isn't full
      TF2_ChangeClientTeam(client, TFTeam_Red); // move that player to red. since this is called for every player, this will move everyone to red
    }
  }
}
public Action post_inventory_application(Event event, const char[] name, bool dontBroadcast){
  // This code will run any time someone receives different items from being either spawn or resupply, and I believe picking up weapons as well.
  // This also allows it to function as an "upon spawn" event, without having to hook too many events.
  int client = GetClientOfUserId(event.GetInt("userid")); // Know who we are dealing with. The event contains a "userid" parameter which is the user ID
  // of the user involved, which we then convert into the entity ID for sourcemod.
  TFClassType class; // define "class" variable

  if(TF2_GetClientTeam(client) == TFTeam_Red){
    class = TFClass_Engineer; // set classes to be the right ones for team
  }
  else{
    class = TFClass_Medic;
  }
  if(TF2_GetPlayerClass(client) != class){
    TF2_SetPlayerClass(client, class); // if they are not playing as the correct class, switch them to it
    TF2_RespawnPlayer(client);
  }
  if(TF2_GetClientTeam(client) == TFTeam_Blue){
    TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary); // Remove their primary and secondary weapons to make zombies melee-only
    TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
    ClientCommand(client, "use tf_weapon_bonesaw"); // Make zombies pull out their melee, so they aren't helpless T-Pose
  }
}

public Action player_death(Event event, const char[] name, bool dontBroadcast){
  int client = GetClientOfUserId(event.GetInt("userid"));
  if(!setup){ // don't do any of this if it's setup
    TF2_ChangeClientTeam(client, TFTeam_Blue); // move dead players to blue
    TF2_RespawnPlayer(client);
    if(GetTeamClientCount(2) == 0){
      int win = CreateEntityByName("game_round_win");
      SetVariantInt(3);
      AcceptEntityInput(win, "SetTeam");
      AcceptEntityInput(win, "RoundWin");
      DispatchSpawn(win);
    }
  }
}

public Action player_team(Event event, const char[] name, bool dontBroadcast){
  if(event.GetInt("team") != 3 && !setup){ // if they are try rejoin red after setup is over
    TF2_ChangeClientTeam(GetClientOfUserId(event.GetInt("userid")), TFTeam_Blue); // move them back to blue
  }
}
