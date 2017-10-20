-module(raft_rpc_erl).

%% raft_rpc
-behaviour(raft_rpc).
-export([send/4, recv/2, get_nearest/2, get_reply_endpoint/1]).

-type endpoint() :: raft_utils:gen_ref().

%% this is a copy of gen_server:cast
-spec send(_, endpoint(), endpoint(), raft_rpc:message()) ->
    ok.
send(_, From, To, Message) ->
    FullMessage = {raft_rpc, From, Message},
    ok = case To of
            {global, GlobalName} ->
                catch global:send(GlobalName, FullMessage);
            {via, Mod, Name} ->
                catch Mod:send(Name, FullMessage);
            LocalName ->
                _ = (catch erlang:send(LocalName, FullMessage)),
                ok
        end.

-spec recv(_, term()) ->
    raft_rpc:message().
recv(_, Message) ->
    Message.

-spec get_nearest(_, [endpoint()]) ->
    endpoint().
get_nearest(_, Endpoints) ->
    case find_local(Endpoints) of
        {ok, Local} ->
            Local;
        false ->
            raft_utils:lists_random(Endpoints)
    end.

-spec get_reply_endpoint(_) ->
    endpoint().
get_reply_endpoint(_) ->
    erlang:self().

%%

-spec find_local([endpoint()]) ->
    {ok, endpoint()} | false.
find_local([]) ->
    false;
find_local([H|T]) ->
    case is_local(H) of
        true  -> {ok, H};
        false -> find_local(T)
    end.

-spec is_local(endpoint()) ->
    boolean().
is_local(Ref) ->
    try
        % а нет ли более простого варианта?
        erlang:node(raft_utils:gen_where(Ref)) =:= node()
    catch error:badarg ->
        false
    end.
