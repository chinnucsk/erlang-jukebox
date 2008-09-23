-module(urlcache).
-behaviour(gen_server).

-define(CACHE_DIR, "ejukebox_cache").
-define(CACHE_LIMIT_K, (1048576 * 2)).

-export([start_link/0]).
-export([cache/1, cache/3, current_downloads/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, urlcache}, ?MODULE, [], []).

cache(Url) ->
    gen_server:cast(urlcache, {cache, Url}).

cache(Url, Pid, Ref) ->
    gen_server:cast(urlcache, {cache, Url, Pid, Ref}).

current_downloads() ->
    gen_server:call(urlcache, current_downloads).

%%---------------------------------------------------------------------------

start_caching(Url) ->
    prune_cache(),
    Filename = local_name_for(Url),
    case get({downloader, Url}) of
	undefined ->
	    CachePid = self(),
	    DownloaderPid = spawn_link(fun () -> download_and_cache(CachePid, Filename, Url) end),
	    put({downloader, Url}, DownloaderPid);
	_DownloaderPid ->
	    ok
    end,
    Filename.

local_name_for(Url) ->
    ?CACHE_DIR ++ "/" ++ hexify(binary_to_list(crypto:sha(Url))) ++ ".cachedata".

hexify([]) ->
    "";
hexify([B | Rest]) ->
    [hex_digit((B bsr 4) band 15), hex_digit(B band 15) | hexify(Rest)].

hex_digit(X) when X < 10 ->
    X + $0;
hex_digit(X) ->
    X + $A - 10.

try_rename(_Source, _Target, 0, PrevError) ->
    exit(PrevError);
try_rename(Source, Target, N, _PrevError) ->
    case file:rename(Source, Target) of
	ok -> ok;
	E = {error, _} ->
	    timer:sleep(200),
	    try_rename(Source, Target, N - 1, E)
    end.

download_and_cache(CachePid, Filename, Url) ->
    case filelib:is_file(Filename) of
	true -> ok;
	false ->
	    PartFilename = Filename ++ ".part",
	    CurlPath = os:find_executable("curl"),
	    CurlPid = execdaemon:run(CurlPath, ["-C", "-", "-o", PartFilename, Url]),
	    execdaemon:terminate(CurlPid),
	    ok = try_rename(PartFilename, Filename, 5, no_previous_error)
    end,
    gen_server:cast(CachePid, {download_done, Url}),
    ok.

prune_cache() ->
    filelib:ensure_dir(?CACHE_DIR ++ "/."),
    [SizeStr | _] = string:tokens(os:cmd("du -sk " ++ ?CACHE_DIR), "\t "),
    Size = list_to_integer(SizeStr),
    if
	Size > ?CACHE_LIMIT_K ->
	    prune_candidate(string:tokens(os:cmd("ls -tr " ++ ?CACHE_DIR), "\r\n")),
	    prune_cache();
	true ->
	    ok
    end.

prune_candidate([]) ->
    no_candidate_available;
prune_candidate([C | Rest]) ->
    case lists:reverse(C) of
	"atadehcac." ++ _ -> %% ".cachedata" backwards
	    file:delete(?CACHE_DIR ++ "/" ++ C),
	    {deleted_candidate, C};
	_ ->
	    prune_candidate(Rest)
    end.

wait_for_completion(LocalFileName, Pid, Ref) ->
    spawn(fun () ->
		  link(Pid),
		  wait_for_completion1(LocalFileName, Pid, Ref)
	  end),
    ok.

wait_for_completion1(LocalFileName, Pid, Ref) ->
    case filelib:is_file(LocalFileName) of
	true ->
	    Pid ! {urlcache, ok, Ref, LocalFileName};
	false ->
	    timer:sleep(200),
	    wait_for_completion1(LocalFileName, Pid, Ref)
    end.

collect_current_downloads([], Urls) ->
    Urls;
collect_current_downloads([{{downloader, Url}, _Pid} | Rest], Urls) ->
    collect_current_downloads(Rest, [Url | Urls]);
collect_current_downloads([_Other | Rest], Urls) ->
    collect_current_downloads(Rest, Urls).

%%---------------------------------------------------------------------------

init(_Args) ->
    {ok, none}.

handle_call(current_downloads, _From, State) ->
    {reply, collect_current_downloads(get(), []), State}.

handle_cast({cache, Url}, State) ->
    start_caching(Url),
    {noreply, State};
handle_cast({cache, Url, Pid, Ref}, State) ->
    LocalFileName = start_caching(Url),
    wait_for_completion(LocalFileName, Pid, Ref),
    {noreply, State};
handle_cast({download_done, Url}, State) ->
    erase({downloader, Url}),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.