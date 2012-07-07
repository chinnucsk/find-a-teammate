-module(security_lib).
-export([logged_in/1]).

logged_in(SessionID) ->
    case boss_session:get_session_data(SessionID, user_id) of
	undefined ->
	    {redirect, [{controller, "security"}, {action, "login"}]};
	_UserId ->
	    true
    end.
