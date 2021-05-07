%%--------------------------------------------------------------------
%% Copyright (c) 2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

%% Collection of functions for creating node dumps
-module(emqx_node_dump).

-export([ sys_info/0
        , app_env_dump/0
        ]).

sys_info() ->
    #{ release     => emqx_app:get_release()
     , otp_version => emqx_vm:get_otp_version()
     }.

app_env_dump() ->
    censor(ets:tab2list(ac_tab)).

censor([]) ->
    [];
censor([{{env, App, Key}, Val} | Rest]) ->
    [{{env, App, Key}, censor([Key, App], Val)} | censor(Rest)];
censor([_ | Rest]) ->
    censor(Rest).

censor(Path, {Key, Val}) when is_atom(Key) ->
    {Key, censor([Key|Path], Val)};
censor(Path, M) when is_map(M) ->
    Fun = fun(Key, Val) ->
                  censor([Key|Path], Val)
          end,
    maps:map(Fun, M);
censor(Path, L = [Fst|_]) when is_tuple(Fst) ->
    [censor(Path, I) || I <- L];
censor(Path, Val) ->
    case Path of
        [password|_] ->
            obfuscate_value(Val);
        [secret|_]  ->
            obfuscate_value(Val);
        _ ->
            Val
    end.

obfuscate_value(Val) when is_binary(Val) ->
    <<"********">>;
obfuscate_value(_Val) ->
    "********".

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

censor_test() ->
    ?assertMatch( [{{env, emqx, listeners}, #{password := <<"********">>}}]
                , censor([foo, {{env, emqx, listeners}, #{password => <<"secret">>}}, {app, bar}])
                ),
    ?assertMatch( [{{env, emqx, listeners}, [{foo, 1}, {password, "********"}]}]
                , censor([{{env, emqx, listeners}, [{foo, 1}, {password, "secret"}]}])
                ).

-endif. %% TEST
