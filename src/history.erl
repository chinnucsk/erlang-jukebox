-module(history).
-behaviour(gen_server).

-export([start/2]).
-export([retrieve/2, record/3, format/4, reset/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start(Name, Maxlength) ->
    io:format("Starting history ~p (maxlength ~p).~n", [Name, Maxlength]),
    gen_server:start_link({local, Name}, history, [Maxlength], []).

retrieve(Name, N) -> gen_server:call(Name, {retrieve, N}).
record(Name, Who, What) -> gen_server:call(Name, {record, Who, What}).

format(Name, Who, Fmt, Args) ->
    gen_server:call(Name, {record, Who, lists:flatten(io_lib:format(Fmt, Args))}).

reset(Name) -> gen_server:call(Name, reset).

init([Maxlength]) ->
    {ok, {Maxlength, []}}.

handle_call({retrieve, N}, _From, State={_Maxlength, History}) ->
    {reply, lists:sublist(History, 1, N), State};
handle_call({record, Who, What}, _From, _State={Maxlength, History}) ->
    {reply, ok, {Maxlength, lists:sublist([{Who, What} | History], 1, Maxlength)}};
handle_call(reset, _From, _State={Maxlength, _History}) ->
    {reply, ok, {Maxlength, []}}.

handle_cast(_Message, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
