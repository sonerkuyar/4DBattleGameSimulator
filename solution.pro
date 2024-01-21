distance(0, 0, 0).  % a dummy predicate to make the sim work.

% distance(Agent, TargetAgent, Distance).
distance(Agent, TargetAgent, Distance) :-
    Distance is abs(Agent.x - TargetAgent.x) + abs(Agent.y - TargetAgent.y).
    

% multiverse_distance(StateId, AgentId, TargetStateId, TargetAgentId, Distance).
multiverse_distance(StateId, AgentId, TargetStateId, TargetAgentId, Distance):-
    state(StateId,Agents,_,_), 
    Agent = Agents.get(AgentId),
    state(TargetStateId,TargetAgents,_,_), 
    TargetAgent = TargetAgents.get(TargetAgentId),
    (Agent.class = wizard -> TravelCost = 2; TravelCost = 5),
    history(StateId,U1,T1,_), history(TargetStateId,U2,T2,_),
    Distance is abs(Agent.x - TargetAgent.x) + abs(Agent.y-TargetAgent.y) + TravelCost*(abs(U1-U2)+abs(T1-T2)).
% nearest_agent(StateId, AgentId, NearestAgentId, Distance).
nearest_agent(StateId, AgentId, NearestAgentId, Distance) :-
    state(StateId, Agents, _, _),
    Agent0 = Agents.AgentId,
    dict_pairs(Agents, _, Pairs),
    
    findall(Dist-TargetId, (
        member(TargetId-TargetAgent, Pairs),
        dif(TargetAgent.name,Agent0.name), % filter out the source agent
        distance(Agent0, TargetAgent, Dist)
    ), TargetDistances),
    keysort(TargetDistances, Sorted),
    member(MinDist-MinId, Sorted),
    
    NearestAgentId = MinId,
    Distance is MinDist.
% nearest_agent_in_multiverse(StateId, AgentId, TargetStateId, TargetAgentId, Distance).
nearest_agent_in_multiverse(StateId, AgentId, TargetStateId, TargetAgentId, Distance):-
    universe_limit(Limit),
    state(StateId,Agents,_,_),
    Agent = Agents.get(AgentId),
    history(StateId,_,_,_),
    findall(
        Distances-TargetStateIds-TargetAgentIds,
    ( between(0, Limit, U2),
    history(TargetStateIds,U2,_,_),
    
    multiverse_distance(StateId,AgentId,TargetStateIds,TargetAgentIds,Distances),
    state(TargetStateIds,TargetAgents,_,_),
    TargetAgent = TargetAgents.get(TargetAgentIds),
    dif(Agent.name, TargetAgent.name)
    

        
        
        
    ),MultiverseDistances),
    keysort(MultiverseDistances, Sorted),
    member(Distance-TargetStateId-TargetAgentId, Sorted).


% num_agents_in_state(StateId+, Name+, NumWarriors-, NumWizards-, NumRogues-).
num_agents_in_state(StateId, Name, NumWarriors, NumWizards, NumRogues):-
    state(StateId, Agents, _, _),
    
    findall(_, (get_dict(_, Agents, Agent),
                Agent.name \= Name,
                Agent.class = warrior), WarriorAgents),
    findall(_, (get_dict(_, Agents, Agent),
                Agent.name \= Name,
                Agent.class = wizard), WizardAgents),
    findall(_, (get_dict(_, Agents, Agent),
                Agent.name \= Name,
                Agent.class = rogue), RogueAgents),
    length(WarriorAgents, NumWarriors),
    length(WizardAgents, NumWizards),
    length(RogueAgents, NumRogues).



% difficulty_of_state(StateId, Name, AgentClass, Difficulty).
difficulty_of_state(StateId, Name, AgentClass, Difficulty):-
    num_agents_in_state(StateId,Name ,NumWarriors, NumWizards, NumRogues),
    (AgentClass = warrior ->
        Difficulty is 5*NumWarriors + 8*NumWizards + 2*NumRogues
        ;
    AgentClass = wizard -> 
        Difficulty is 2*NumWarriors + 5*NumWizards + 8*NumRogues
        ;
        Difficulty is 8*NumWarriors + 2*NumWizards + 5*NumRogues
    ).

step_universe_check_with_action(StateId,AgentId, [ActionHead|ActionArgs],TargetStateId, TgtDifficulty) :-
    state(StateId, Agents, _, TurnOrder),
    history(StateId, UniverseId, Time, _),
    Agent = Agents.get(AgentId),
    can_perform(Agent.class, ActionHead),
    
    (
    (ActionHead = portal ->
            % check whether global universe limit has been reached
            global_universe_id(GlobalUniverseId),
            universe_limit(UniverseLimit),
            GlobalUniverseId < UniverseLimit,
            % agent cannot time travel if there is only one agent in the universe
            length(TurnOrder, NumAgents),
            NumAgents > 1,
            [TargetUniverseId, TargetTime] = ActionArgs,
            % check whether target is now or in the past
            current_time(TargetUniverseId, TargetUniCurrentTime, _),
            TargetTime < TargetUniCurrentTime,
            % check whether there is enough mana
            (Agent.class = wizard -> TravelCost = 2; TravelCost = 5),
            Cost is abs(TargetTime - Time)*TravelCost + abs(TargetUniverseId - UniverseId)*TravelCost,
            Agent.mana >= Cost,
            % check whether the target location is occupied
            get_earliest_target_state(TargetUniverseId, TargetTime, TargetStateId),
            state(TargetStateId, TargetAgents, _, TargetTurnOrder),
            TargetState = state(TargetStateId, TargetAgents, _, TargetTurnOrder),
            \+tile_occupied(Agent.x, Agent.y, TargetState),
            difficulty_of_state(TargetStateId, Agent.name, Agent.class, TgtDifficulty),
            TgtDifficulty > 0
            
        );
        (ActionHead = portal_to_now ->
            % agent cannot time travel if there is only one agent in the universe
            length(TurnOrder, NumAgents),
            NumAgents > 1,
            [TargetUniverseId] = ActionArgs,
            % agent can only travel to now if it's the first turn in the target universe
            current_time(TargetUniverseId, TargetTime, 0),
            % agent cannot travel to current universe's now (would be a no-op)
            \+(TargetUniverseId = UniverseId),
            % check whether there is enough mana
            (Agent.class = wizard -> TravelCost = 2; TravelCost = 5),
            Cost is abs(TargetTime - Time)*TravelCost + abs(TargetUniverseId - UniverseId)*TravelCost,
            Agent.mana >= Cost,
            % check whether the target location is occupied
            get_latest_target_state(TargetUniverseId, TargetTime, TargetStateId),
            state(TargetStateId, TargetAgents, _, TargetTurnOrder),
            TargetState = state(TargetStateId, TargetAgents, _, TargetTurnOrder),
            \+tile_occupied(Agent.x, Agent.y, TargetState),
            difficulty_of_state(TargetStateId, Agent.name, Agent.class, TgtDifficulty),
            TgtDifficulty > 0



            
            
           
        )
    ).


% easiest_traversable_state(StateId, AgentId, TargetStateId).
easiest_traversable_state(StateId, AgentId, TargetStateId):-
    universe_limit(Limit),
    findall(
        TgtDifficulty-TargetStateIds,
    ( between(0, Limit, Value),
        step_universe_check_with_action(StateId,AgentId, [portal_to_now,Value],TargetStateIds, TgtDifficulty)
        
        ),TargetStatesPortalToNow),
    findall(
        TgtDifficulty-TargetStateIds,
        (between(0, Limit, Value),
        history(_,Value,TargetTime,_),
        
        step_universe_check_with_action(StateId,AgentId, [portal,[Value,TargetTime]],TargetStateIds, TgtDifficulty)
        

            ),
            TargetStatesPortal
        ),
    state(StateId,Agents,_,_),
    Agent = Agents.get(AgentId),
    difficulty_of_state(StateId,Agent.name,Agent.class, CurrentDiff),
    
    

    append(TargetStatesPortal, [CurrentDiff-StateId|TargetStatesPortalToNow], AllTargetStates),
    keysort(AllTargetStates, Sorted),
    member(_-TargetStateId,Sorted).
    

% basic_action_policy helper functions.
melee_attack_available(StateId,AgentId,AttackId):-
    nearest_agent(StateId,AgentId,AttackId,Distance),
    state(StateId,Agents,_,_),
    
    AgentSource = Agents.get(AgentId),
    AgentSource.class= warrior,
    + Distance  =< 1.
magic_missile_available(StateId,AgentId,AttackId):-
    nearest_agent(StateId,AgentId,AttackId,Distance),
    state(StateId,Agents,_,_),
    
    AgentSource = Agents.get(AgentId),
    AgentSource.class= wizard,
    + Distance  =< 10.
ranged_attack_available(StateId,AgentId,AttackId):-
    nearest_agent(StateId,AgentId,AttackId,Distance),
    state(StateId,Agents,_,_),
    
    AgentSource = Agents.get(AgentId),
    AgentSource.class = rogue,
    
    + Distance  =< 5.



where_to_move(StateId,AgentId,MoveAction):-
    nearest_agent(StateId,AgentId,NearestId,_),
    
    
    state(StateId, Agents, CurrentTurn, TurnOrder),
    SourceAgent = Agents.get(AgentId),
    TargetAgent = Agents.get(NearestId),
    State = state(StateId, Agents, CurrentTurn, TurnOrder),
    
    (TargetAgent.y > SourceAgent.y
     -> 
        Yn is SourceAgent.y + 1,
        \+tile_occupied(SourceAgent.x, Yn, State),
        MoveAction = [move_up],!
    ;
    TargetAgent.x > SourceAgent.x
     -> 
        Xn is SourceAgent.x + 1,
        \+tile_occupied(Xn, SourceAgent.y, State),
        MoveAction = [move_right],!
    ;
    TargetAgent.y < SourceAgent.y
     -> 
        Yn is SourceAgent.y - 1,
        \+tile_occupied(SourceAgent.x, Yn, State),
        MoveAction = [move_down],!
    ;
    
    TargetAgent.x < SourceAgent.x
     -> 
        Xn is SourceAgent.x - 1,
        \+tile_occupied(Xn, SourceAgent.y, State),
        MoveAction = [move_left],!
    ).

 
% basic_action_policy(StateId, AgentId, Action).
basic_action_policy(StateId, AgentId, Action):-
    easiest_traversable_state(StateId,AgentId,TargetStateId),
    history(TargetStateId, TargetUniverseId,TargetTime,_),
    history(StateId,_,Time,_),
    state(StateId,_,_,_),
    (   TargetStateId = StateId 
    ->  (ranged_attack_available(StateId,AgentId,AttackId)
        -> Action = [ranged_attack,AttackId],!
        ;
        magic_missile_available(StateId,AgentId,AttackId)
        -> Action = [magic_missile,AttackId],!
        ;
        melee_attack_available(StateId,AgentId,AttackId)
        -> Action = [melee_attack,AttackId],!
        ;
        where_to_move(StateId,AgentId,MoveAction)->
        Action = MoveAction,!
        ;
        Action = [rest]
    ),!
    ; 
    TargetTime = Time 
    ->
    Action = [portal_to_now, TargetUniverseId],!
    ;
    Action = [portal,[TargetUniverseId,TargetTime]]
    ).



