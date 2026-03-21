-module(vg_server_ffi).
-export([get_env/1, timestamp_ms/0, generate_token/0]).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

timestamp_ms() ->
    erlang:system_time(millisecond).

generate_token() ->
    Bytes = crypto:strong_rand_bytes(32),
    list_to_binary(lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bytes])).
