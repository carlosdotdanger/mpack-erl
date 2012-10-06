-module(mpack_tests).

-import(mpack, [pack/1, unpack/1,chk_msg/1]).

-include_lib("eunit/include/eunit.hrl").


array_test_()->
    [
        {"fix", assert_pack(lists:seq(1,8))},
        {"16", assert_pack(lists:seq(0, 1024))},
        {"32",assert_pack(lists:seq(0, 666666))},
        {"empty",assert_pack([])},
        {"rather_large" , assert_pack(rather_large(759))}
    ].


map_test_()->
    [
        {"fix",assert_pack([ {X, X * 2} || X <- lists:seq(0, 5) ])},        
        {"16", assert_pack([ {X, X * 2} || X <- lists:seq(0, 16) ])},
        {"32", assert_pack([ {X, X * 2} || X <- lists:seq(0, 16#010000) ])},
        {"empty",assert_pack([])}
    ].

int_test_() ->
    [
        {"fix pos",assert_pack(3)},
        {"fix neg",assert_pack(-15)},
        {"int",assert_pack(-2147483649)}
    ].

badpack_test_()->
    [
        {"tuple" , assert_pack_error({derp, 1, doooooog})},
        {"tuple_array" , assert_pack_error([76254235,{1}])},
        {"looks_like_a_map!" , assert_pack_error([{key,value},872387234])},
        {"function_packing", assert_pack_error(fun() -> ok end)}
    ].

bad_unpack_test_() ->
    [
        {"nonsense",assert_unpack_error(badpoop)},
        {"int",  assert_unpack_error(23478348)},
        {"tuple",assert_unpack_error({foop,doop})}
    ].

binary_test_() ->
    [
        {"empty", assert_pack(<<>>)},
        {"fix",   assert_pack(<<1,2,3>>)}
    ].

msg_chk_test_()->
    [
        {"good_chk", assert_chk(small())},
        {"not_packed", assert_chk_fail(small())},
        {"invalid_bin", assert_chk_fail(small_bin())},
        {"truncated", assert_chk_trnc(small(), 5)},
        {"truncated", assert_chk_trnc(small(), 7)},
        {"truncated", assert_chk_trnc(small(), 28)}

    ].

%HELPERZ
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
assert_pack(Term)->
    fun() -> 
        Binary = pack(Term),
        ?assertEqual({ok,Term}, unpack(Binary))
    end.

assert_pack_error(Term)->
    fun() -> 
        ?assertMatch({error,{badarg, _ } }, pack(Term))
    end.

assert_unpack_error(Bin)->
    fun() -> 
        ?assertMatch({error,{badarg, _ } }, unpack(Bin))
    end.

assert_chk(Val) ->
    fun() ->
        ?assertEqual(ok,chk_msg(pack(Val)))
    end.

assert_chk_fail(Val)->
    fun() ->
        ?assertMatch({error,{_,_}},chk_msg(Val))
    end.

assert_chk_trnc(Val,Clip)->
    fun() ->
        <<H:Clip/binary,_T/binary>> = pack(Val),
        ?assertMatch({error,{_,_}},chk_msg(H))
    end.

small()->
    [<<"hello">>,45,[{<<"I am">>,<<"a prop list">>},{24,9.7},{<<"jasjd">>,98732899999}],lists:seq(1,100)].

rather_large(N)-> [ small() || _X <- lists:seq(1,N)].

small_bin() -> <<"hello stranger!">>.
