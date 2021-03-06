-module(spawnfest_member_controller, [Req, SessionID]).
-compile(export_all).

before_(Function) ->
    error_logger:info_msg("Function: ~p~n", [Function]),
	case Function of
	"create" ->
		security:logged_in(SessionID, "signup");
	AnythingElse ->
		security:logged_in(SessionID, Function)
	end.

index('GET', []) ->
    Members = boss_db:find(member, []),
    [Assigned, Unassigned] = separate_members(Members),
    %% error_logger:info_msg("We have ~p Assigned and ~p Unassigned Members", [length(Assigned), length(Unassigned)]),
    Teams = boss_db:find(team, []),
    {ok, [{assigned, Assigned}, {unassigned, Unassigned}, {teams, Teams}, {members, Members}]}.

show('GET', [Id]) ->
    Member = boss_db:find(Id),
    {ok, [{member, Member}]}.

create('GET', []) ->
    %% TODO: Find teams that has less than 4 team members
    Teams = boss_db:find(team, []),
    {ok, [{teams, Teams}]};
create('POST', []) ->
    First = Req:post_param("first"),
    Last = Req:post_param("last"),
    Email = Req:post_param("email"),
    City = Req:post_param("city"),
    Country = Req:post_param("country"),
    State = Req:post_param("state"),
    GitAccount = Req:post_param("github"),
    Rank = (boss_db:find_first(rank, [{name, "Rookie"}])):id(),
    TeamId = Req:post_param("team"),
    
    PasswordHash = mochihex:to_hex(crypto:sha256(Req:post_param("password"))),
    NewMember = member:new(id, TeamId, First, Last, Email, City, Country, State, GitAccount, Rank, PasswordHash),

    case NewMember:save() of
	{ok, SavedMember} ->
	    boss_flash:add(SessionID, success, "Thank you for signing up"),
	    boss_session:set_session_data(SessionID, thankyou_id, SavedMember:id()),
	    case SavedMember:team_id() of
		[] ->
		    TeamsNow = [binary_to_list(X:name()) || X <- boss_db:find(team, [])],
		    (noteam:new(id, Email, TeamsNow)):save(),
		    {redirect, [{action, "thankyou"}]};
		Id ->
		    {redirect, [{action, "thankyou"}]};
		{error, Reason} ->
		    boss_flash:add(SessionID, error, "Signup failed.  Please try again later"),
		    Reason
	    end;
	{error, Reason} ->
		boss_flash:add(SessionID, error, Reason)
    end.

edit('GET', [Id]) ->
    Member = boss_db:find(Id),
    {ok, [{member, Member}]};
edit('POST', [Id]) ->
    OldMember = boss_db:find(Id),
    %% [Id, TeamId, First, Last, Email, City, Country, State, GitAccount, Rank, PasswordHash]).
    %% TeamId = Req:post_param("team"),
    First = Req:post_param("first"),
    Last = Req:post_param("last"),
    Email = Req:post_param("email"),
    City = Req:post_param("city"),
    Country = Req:post_param("country"),
    State = Req:post_param("state"),
    GitAccount = Req:post_param("gitaccount"),
    Rank = Req:post_param("rank"),
    
    NewMember = OldMember:set([
			       {first, First},
			       {last, Last},
			       {email, Email},
			       {city, City},
			       {country, Country}
			      ]),
    case NewMember:save() of
	{ok, Updated} ->
	    boss_flash:add(SessionID, success, "Updated Member"),
	    {redirect, [{action, "index"}]};
	{error, Reason} ->
	    Reason
    end.

destroy('GET', [Id]) ->
    Member = boss_db:find(Id),
    error_logger:info_msg("Deleting Member ~s ~s~n", [Member:first(), Member:last()]),
    boss_db:delete(Id),
    {redirect, [{action, "index"}]}.

email('GET', [Id]) ->
    Member = boss_db:find(Id),
    {ok, [{member, Member}]};
email('POST', [Id]) ->
    Member = boss_db:find(Id),
    Subject = Req:post_param("subject"),
    Body = Req:post_param("body"),
    Msg = lists:flatten("Sent email to member ~s", [Member:email()]),
    error_logger:info_msg(Msg),
    boss_mail:send("admin@router1.is-a-geek.org", binary_to_list(Member:email()), Subject, Body),
    boss_flash:add(SessionID, success, Msg),
    {redirect, [{action, "index"}]}.

assign('GET', [Id]) ->
    Member = boss_db:find(Id),
    Teams = boss_db:find(team, []),
    {ok, [{member, Member}, {teams, Teams}]};
assign('POST', [Id]) ->
    OldMember = boss_db:find(Id),
    TeamId = Req:post_param("team"),
    Team = boss_db:find(TeamId),
    NewMember = OldMember:set([{team_id, Team:id()}]),

    case NewMember:save() of
	{ok, Saved} ->
	    Msg = lists:flatten(io_lib:format("Added \"~s ~s\" to Team \"~s\"", [OldMember:first(), OldMember:last(), Team:name()])),
	    error_logger:info_msg("POST received with Id ~s", [Id]),
	    boss_flash:add(SessionID, success, Msg),
	    {redirect, [{action, "index"}]};
	{error, Reason} ->
	    Reason
    end.

thankyou('GET', []) ->
    Member = boss_db:find( boss_session:get_session_data(SessionID, thankyou_id)),
    {ok, [{member, Member}]}.

separate_members(Members) ->
    separate_members(Members, [], []).

separate_members([], Assigned, Unassigned) ->
    [lists:reverse(Assigned), lists:reverse(Unassigned)];
separate_members([H | Members], Assigned, Unassigned) ->
    case H:team_id() of
	[] ->
	    separate_members(Members, Assigned, [H|Unassigned]);
	Id ->
	    separate_members(Members, [H|Assigned], Unassigned)
    end.
