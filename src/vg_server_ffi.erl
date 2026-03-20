-module(vg_server_ffi).
-export([get_env/1, timestamp_ms/0]).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

timestamp_ms() ->
    erlang:system_time(millisecond).
