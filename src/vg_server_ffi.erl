-module(vg_server_ffi).
-export([get_env/1, timestamp_ms/0, generate_token/0, generate_anonymous_player/0]).

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

generate_anonymous_player() ->
    Adjectives = [<<"Swift">>, <<"Mystic">>, <<"Shadow">>, <<"Golden">>, <<"Fierce">>,
                  <<"Silent">>, <<"Crimson">>, <<"Storm">>, <<"Ember">>, <<"Frost">>,
                  <<"Thunder">>, <<"Crystal">>, <<"Rogue">>, <<"Noble">>, <<"Ancient">>],
    Nouns = [<<"Fox">>, <<"Wolf">>, <<"Dragon">>, <<"Phoenix">>, <<"Hawk">>,
             <<"Bear">>, <<"Tiger">>, <<"Raven">>, <<"Lion">>, <<"Falcon">>,
             <<"Viper">>, <<"Panther">>, <<"Griffin">>, <<"Sphinx">>, <<"Hydra">>],
    Random = rand:uniform(15),
    Adj = lists:nth(Random, Adjectives),
    Noun = lists:nth(Random, Nouns),
    Num = rand:uniform(99),
    PlayerId = list_to_binary(io_lib:format("anon_~6.6.0b", [rand:uniform(999999)])),
    DisplayName = list_to_binary(io_lib:format("~s~s~2.2.0b", [Adj, Noun, Num])),
    #{player_id => PlayerId, display_name => DisplayName}.
