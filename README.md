# DCS auto GCI/CAP and BVR AI enhancements

## Quick start AI manager only
AiHandler replaces predefined in editor groups, with groups controlled by script, allowing them using tactics and work in more coordinated way

* Create handler, with corresponding coalition(```AiHandler.coalition.RED/AiHandler.coalition.BLUE```)
```local handler = AiHandler:create(AiHandler.coalition.RED)```
* Add existing group directrly by name 
```handler:addCapGroupByName(MyGroup1) ```
* Or add all groups with prefix
```handler:addCapGroupsByPrefix()```
* Add radars:
1. Add all EWR in coalition 
```handler:addEWs()``` or
2. Add radar unit directly 
```handler:addRadar(Unit.getByName("Radar1"))``` 
* Start mainloop
```handler:start()```

## GCICAP Handler
Automated air defence for coalition, dynamically add new groups, to counter air threat to objectives


* Quick defence setup for coalition, first arg is prefix of groups which will used as squadron template, second arg is prefix of trigger zone

```local handlerRed = GciCapHandler:createDefenceForRed("redCap", "redCapZone")```
```local handlerBlue = GciCapHandler:createDefenceForBlue("blueCap", "blueCapZone")```

* Or Create handler. with corresponding coalition(```GciCapHandler.coalition.RED/GciCapHandler.coalition.BLUE```)
```local handler = GciCapHandler:create(GciCapHandler.coalition.RED)```
* Add radar same as for AiHandler
```handler:addEWs()```
```handler:addRadar(Unit.getByName("Radar1"))``` 
* Create squadron, squadron will use group first unit as template, will inherit spawn location, unit type, loadout
```local sqn = CapSquadron:create(groupName, aircraftReady, aircraftTotal, preflightTime, combatRange, priority)```
    * groupName - name of group in mission editor
    * aircraftReady - number of aircraft on alert, they will spawn immidiatly
    * aircraftTotal - total amount of aircraft of squadron, they need preflightTime to make preflight checks before flight
    * preflightTime - how much time to prepare aircraft to alert state
    * priority - High priority will use first, avail values: 
        ```CapSquadronAir.Priority.LOW```
        ```CapSquadronAir.Priority.NORMAL```
        ```CapSquadronAir.Priority.HIGH```
```local squadron = CapSquadron:create("CAP", 2, 4, 1500, 250*100, CapSquadron.Priority.NORMAL)```
* Create Objective which handler will defend, can be created from trigger zone:
    ```CapObjective.makeFromTriggerZone(triggerZoneName, useForCap, useForGci, priority)```
        * triggerZoneName - string
        * useForCap - bool
        * useForGci - bool
        * priority - CapObjective.Priority.Low/CapObjective.Priority.Normal/CapObjective.Priority.High
    * or from group route, where route is bounding polygon
    ```CapObjective.makeFromGroupRoute(groupName, useForCap, useForGci, priority)```
        * groupName - string
        * useForCap - bool
        * useForGci - bool
        * priority - CapObjective.Priority.Low/CapObjective.Priority.Normal/CapObjective.Priority.High
    * or generate from squadron, will create with radius R at squdron home base
    ```sqn:generateObjective(R)```
        * R - number, radius in meters, default 200km
* add objective to handler
```local obj = CapObjective.makeFromTriggerZone("zone", true, true)```
```handler:addObjective(obj)```
* add squadron to handler, will optionally create objective at home base
```handler:addSquadron(sqn, generateObj, objRadius)```
    * generateObj - bool, should create with objRadius at home base
    * objRadius - number, default 200km
* start handler
```handler:start()```

# Group settings
Setting applyed to each instance of group/squadron, all groups also can be accessed by
```AiHandlerInstance:getCapGroups()```
And squadrons 
```GciCapHandlerInstance:getSquadrones()```
Return table allows chaining:
```AiHandlerInstance:getCapGroups():setBingo(0.3):setALR(CapGroup.ALR.Normal)```

Squadrons and groups share same settings:
* ```SquadronOrCapGroup:setBingo(bingo)```
    * bingo - number, at which fuel state will return to base, 0 - empty 1 - full internal
* ```SquadronOrCapGroup:setRTBWhen(rtbWhen)```
    * rtbWhen - enum, which weapon state should RTB 
        * ```CapGroup.RTBWhen.NoAmmo```
        * ```CapGroup.RTBWhen.IROnly```
        * ```CapGroup.RTBWhen.NoARH ```
* ```SquadronOrCapGroup:setDeactivateWhen(val)```
     * val - enum, when delete group
        * CapGroup.DeactivateWhen.InAir
        * CapGroup.DeactivateWhen.OnLand
        * CapGroup.DeactivateWhen.OnShutdown
* ```SquadronOrCapGroup:setPriorities(modifierFighter, modifierAttacker, modifierHeli)```
    * modifierFighter - number, modifier for fighter aircraft, default 1
    * modifierAttacker - attacker/not fighter aircraft, default 0.5
    * modifierHeli - helicopters, default 0.1
* ```SquadronOrCapGroup:setALR(val)```
    * val - enum, Normal ALR recommended for Fox3/more or less equal adversaries or controlled group will go to pump at MAR before enter engage zone
        *```CapGroup.ALR.Normal```
        *```CapGroup.ALR.High```  ignore MAR, go cold only if attacked
* ```SquadronOrCapGroup:setTactics(tacticsList)```
    * tacticsList - array of enums
        * ```CapGroup.tactics.Skate```
        * ```CapGroup.tactics.SkateGrinder```
        * ```CapGroup.tactics.SkateOffset```
        * ```CapGroup.tactics.SkateOffsetGrinder```
        * ```CapGroup.tactics.ShortSkate```
        * ```CapGroup.tactics.ShortSkateGrinder```
        * ```CapGroup.tactics.Bracket```
        * ```CapGroup.tactics.Banzai```
* ```SquadronOrCapGroup:setGoLiveThreshold(goLiveAmount)```
    * goLiveAmount - number, group will use own radar if not covered by this amount of radars