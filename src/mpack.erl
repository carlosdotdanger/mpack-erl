-module (mpack).
-include ("mpack.hrl").
-export ([pack/1,unpack/1,chk_msg/1]).

%%API
unpack(Dat)->
	case dcode(Dat) of 
		{ok,Val,<<>>} -> {ok,Val};
		Err -> Err
	end.

pack([{K,V}|T]) ->  ncode_map([{K,V}|T]);
pack(N) when is_list(N)  ->  ncode_arr(N);
pack(nil) -> <<?NIL>>;
pack(true) -> <<?TRUE>>;
pack(false) -> <<?FALSE>>;
pack(N) when is_integer(N)->
	case N < 0 of
		true -> ncode_si(N);
		false -> ncode_unsi(N)
	end;
pack(N) when is_float(N) -> << ?DOUBLE, N:64/big-float >>;
pack(N) when is_atom(N)  -> pack(list_to_binary(atom_to_list(N)));
pack(N) when is_binary(N)-> 
	case byte_size(N) of
		Sz when Sz < 32    -> <<?FIX_RAW,Sz:5,N/binary >>;
		Sz when Sz < 65536 -> <<?RAW_16 ,Sz:16,N/binary>>;
		Sz -> <<?RAW_32,Sz:32,N>>
	end;
pack(N) -> {error,{badarg,N}}.

%%INTERNAL
ncode_si(N) when N >= ?MIN_5  -> <<?FIX_NEG,N:5>>;
ncode_si(N) when N >= ?MIN_8  -> <<?INT_8,N:8/signed-integer>>;
ncode_si(N) when N >= ?MIN_16 -> <<?INT_16,N:16/big-signed-integer>>;
ncode_si(N) when N >= ?MIN_32 -> <<?INT_32,N:32/big-signed-integer>>;
ncode_si(N) -> <<?INT_64,N:64/big-signed-integer>>.

ncode_unsi(N) when N =< ?MAX_U7  -> <<?FIX_POS,N:7>>;
ncode_unsi(N) when N =< ?MAX_U8  -> <<?UINT_8,N:8/big-unsigned-integer>>;
ncode_unsi(N) when N =< ?MAX_U16 -> <<?UINT_16,N:16/big-unsigned-integer>>;
ncode_unsi(N) when N =< ?MAX_U32 -> <<?UINT_32,N:32/big-unsigned-integer>>;
ncode_unsi(N) -> <<?UINT_64,N:64/big-unsigned-integer>>.

ncode_map(Map) ->
	Acc = case length(Map) of
		Sz when Sz =< ?MAX_U4  -> <<?FIX_MAP,Sz:4>>;
		Sz when Sz =< ?MAX_U16 -> <<?MAP_16,Sz:16/unsigned-integer>>;
		Sz when Sz =< ?MAX_U32 -> <<?MAP_32,Sz:32/unsigned-integer>>
	end,
	ncode_map(Map,Sz,Acc).
ncode_map([],0,Acc)-> Acc;
ncode_map([{K,V}|T],Sz,Acc)->
	case pack(K) of
		{error,Reason} -> {error,Reason};
		PK ->
			case pack(V) of
				{error,Reason} -> {error,Reason};
				PV ->
					ncode_map(T,Sz-1,<<Acc/binary,PK/binary,PV/binary>>)
			end
	end;
ncode_map(Err,_Sz,_Acc) -> {error,{badarg,Err}}.

ncode_arr(Arr) ->
	Acc = case length(Arr) of
		Sz when Sz =< ?MAX_U4  -> <<?FIX_ARR,Sz:4>>;
		Sz when Sz =< ?MAX_U16 -> <<?ARR_16,Sz:16/unsigned-integer>>;
		Sz when Sz =< ?MAX_U32 -> <<?ARR_32,Sz:32/unsigned-integer>>
	end,
	ncode_arr(Arr,Sz,Acc).
ncode_arr([],0,Acc) -> Acc;
ncode_arr([H|T],Sz,Acc) ->
	case pack(H) of
		{error,Reason} -> {error,Reason};
		PH ->
			ncode_arr(T,Sz-1,<<Acc/binary,PH/binary>>)
	end;
ncode_arr(Err,_Sz,_Acc) -> {error,{badarg,Err}}.

dcode(<<?NIL,Dat/binary>>)  -> {ok,nil,Dat};
dcode(<<?FALSE,Dat/binary>>)-> {ok,false,Dat};
dcode(<<?TRUE,Dat/binary>>) -> {ok,true,Dat};
dcode(<<?FLOAT,Val:32/float,Dat/binary>>)    	-> {ok,Val,Dat};
dcode(<<?DOUBLE,Val:64/float,Dat/binary>>)   	-> {ok,Val,Dat};
dcode(<<?UINT_8,Val:8/unsigned,Dat/binary>>)	-> {ok,Val,Dat};
dcode(<<?UINT_16,Val:16/unsigned,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?UINT_32,Val:32/unsigned,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?UINT_64,Val:64/unsigned,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?INT_8,Val:8/big-signed-integer,Dat/binary>>)   -> {ok,Val,Dat};
dcode(<<?INT_16,Val:16/big-signed-integer,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?INT_32,Val:32/big-signed-integer,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?INT_64,Val:64/big-signed-integer,Dat/binary>>) -> {ok,Val,Dat};
dcode(<<?RAW_16,Sz:16/unsigned,Dat/binary>>) ->
	<<Val:Sz/binary,LessDat/binary>> = Dat,
	{ok,Val,LessDat};
dcode(<<?RAW_32,Sz:32/unsigned,Dat>>) ->
	<<Val:Sz/binary,LessDat/binary>> = Dat,
	{ok,Val,LessDat};
dcode(<<?ARR_16,Sz:16/unsigned,Dat/binary>>) -> dcode_arr(Dat,Sz);
dcode(<<?ARR_32,Sz:32/unsigned,Dat/binary>>) -> dcode_arr(Dat,Sz);
dcode(<<?MAP_16,Sz:16/unsigned,Dat/binary>>) -> dcode_map(Dat,Sz);
dcode(<<?MAP_32,Sz:32/unsigned,Dat/binary>>) -> dcode_map(Dat,Sz);
dcode(<<?FIX_NEG,Vl:5/unsigned-integer,Dat/binary>>) -> {ok,Vl + ?MIN_5,Dat};
dcode(<<?FIX_POS,Val:7,Dat/binary>>)   -> {ok,Val,Dat};
dcode(<<?FIX_MAP,Sz:4, Dat/binary>>) -> dcode_map(Dat,Sz);
dcode(<<?FIX_ARR,Sz:4, Dat/binary>>) -> dcode_arr(Dat,Sz);
dcode(<<?FIX_RAW,Sz:5, Dat/binary>>) ->
	<<Val:Sz/binary,LessDat/binary>> = Dat, 
	{ok,Val,LessDat};
dcode(Err) -> {error,{badarg,Err}}.

dcode_arr(Dat,Sz)  -> dcode_arr(Dat,Sz,queue:new()).
dcode_arr(Dat,0,Acc) -> {ok,queue:to_list(Acc),Dat};
dcode_arr(Dat,Sz,Acc)->
	{ok,Val,LessDat} = dcode(Dat),
	dcode_arr(LessDat,Sz-1,queue:in(Val,Acc)).

dcode_map(Dat,Sz) -> dcode_map(Dat,Sz,queue:new()).
dcode_map(Dat,0,Acc) -> {ok,queue:to_list(Acc),Dat};
dcode_map(Dat,Sz,Acc)->
	{ok,Key,LessDat} = dcode(Dat),
	{ok,Val,EvenLessDat} = dcode(LessDat),	
	dcode_map(EvenLessDat,Sz-1,queue:in({Key,Val},Acc)).


%checks source for valid format/length
chk_msg(<<>>) ->
	{error,empty};
chk_msg(Dat) when is_binary(Dat) ->
    case chk_read(Dat) of
    	{ok,<<>>} -> ok;
    	Err -> {error,Err}
    end;
chk_msg(Dat)->
	{error,{not_packed,Dat}}.
chk_read(Dat)->
    <<Byte:1/binary,Left/binary>> = Dat,
	chk_read(Byte,Left).
chk_read(<<?NIL>>,Dat) 		-> 	{ok,Dat};
chk_read(<<?FALSE>>,Dat)	-> 	{ok,Dat};
chk_read(<<?TRUE>>,Dat)	 	-> 	{ok,Dat};
chk_read(<<?FLOAT>>,Dat) 	->  next_bytes(4,Dat);
chk_read(<<?DOUBLE>>,Dat) 	-> 	next_bytes(8,Dat);
chk_read(<<?UINT_8>>,Dat) 	-> 	next_bytes(1,Dat);
chk_read(<<?UINT_16>>,Dat) 	->  next_bytes(2,Dat);
chk_read(<<?UINT_32>>,Dat) 	->	next_bytes(4,Dat);
chk_read(<<?UINT_64>>,Dat)  ->	next_bytes(8,Dat);
chk_read(<<?INT_8>>,Dat) 	-> 	next_bytes(1,Dat);
chk_read(<<?INT_16>>,Dat) 	->  next_bytes(2,Dat);
chk_read(<<?INT_32>>,Dat) 	->	next_bytes(4,Dat);
chk_read(<<?INT_64>>,Dat)   ->	next_bytes(8,Dat);
chk_read(<<?RAW_16>>,Dat) ->
    <<Sz:16/big-unsigned-integer,Left/binary>> = Dat,
    next_bytes(Sz,Left);
chk_read(<<?RAW_32>>,Dat) ->
    <<Sz:32/big-unsigned-integer,Left/binary>> = Dat,
    next_bytes(Sz,Left);
chk_read(<<?ARR_16>>,Dat) ->
    <<Sz:16/big-unsigned-integer,Left/binary>> = Dat,
    chk_read_arr(Left,Sz);
chk_read(<<?ARR_32>>,Dat) ->
    <<Sz:32/big-unsigned-integer,Left/binary>> = Dat,
    chk_read_arr(Left,Sz);
chk_read(<<?MAP_16>>,Dat) ->
    <<Sz:16/big-unsigned-integer,Left/binary>> = Dat,
    chk_read_map(Left,Sz);
chk_read(<<?MAP_32>>,Dat) ->
    <<Sz:32/big-unsigned-integer,Left/binary>> = Dat,
    chk_read_map(Left,Sz);
chk_read(<<?FIX_NEG,_Val:5>>,Dat) 	-> {ok,Dat};
chk_read(<<?FIX_POS,_Val:7>>,Dat) 	-> {ok,Dat};
chk_read(<<?FIX_MAP,Sz:4>>,  Dat) 	-> chk_read_map(Dat,Sz);
chk_read(<<?FIX_ARR,Sz:4>>,  Dat) 	-> chk_read_arr(Dat,Sz);
chk_read(<<?FIX_RAW,Sz:5>> , Dat) 	->
    case Sz of
    	%empty strings happen!
        0 -> {ok,Dat};
        _ -> next_bytes(Sz,Dat)
    end;
chk_read(Err,Dat) ->
    {badarg,[Err,Dat]}.

chk_read_arr(Dat,0) -> {ok,Dat};
chk_read_arr(<<>>,Sz) -> {truncated_array,Sz};
chk_read_arr(Dat,Sz)->
    case chk_read(Dat) of
        {ok,Left} -> chk_read_arr(Left,Sz-1);
        Err -> Err
    end.

chk_read_map(Dat,0) -> {ok,Dat};
chk_read_map(<<>>,Sz) -> {truncated_map,Sz};
chk_read_map(Dat,Sz)->
    case chk_read(Dat) of
        {ok,Left1} ->
            case chk_read(Left1) of
                {ok,Left2} ->
                	chk_read_map(Left2,Sz-1);
                Err -> Err
            end;
        Err -> Err
    end.

next_bytes(X,Dat)->
	<<_Thing:X/binary,Left/binary>> = Dat,
	{ok,Left}.
