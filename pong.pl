:- dynamic input_char/1.

enable_raw_mode :-
    shell('stty raw').

execute_command(Command, Output) :-
    open(pipe(Command), read, Stream),
    read_string(Stream, _, OutputWithNewline),
    sub_string(OutputWithNewline, 0, _, 1, Output),
    close(Stream).

get_term_size(Width, Height) :-
    execute_command('tput cols', WidthStr),
    execute_command('tput lines', HeightStr),
    atom_number(WidthStr, Width),
    atom_number(HeightStr, Height).

disable_raw_mode :-
    shell('stty -raw').

show_cursor :-
    write('\033[?25h').

hide_cursor :-
    write('\033[?25l').

enter_alt_screen :-
    write('\033[?1049h').

exit_alt_screen :-
    write('\033[?1049l').

move_cursor(Column, Row) :-
    format('\e[~d;~dH', [floor(Row), floor(Column)]).

char_at(Column, Row, Char) :-
    format('\e[~d;~dH~s', [floor(Row), floor(Column), Char]).

initial_state :-
    retractall(ball_state(_, _, _, _)), % posx, posy, velx, vely
    assertz(ball_state(2, 2, 1, 0.5)),
    retractall(player1(_, _)), % paddle, score
    assertz(player1(10, 0)),
    retractall(player2(_, _)), % paddle, score
    assertz(player2(10, 0)).

abs(X, X) :-
    X >= 0.

abs(X, AbsX) :-
    X < 0,
    AbsX is -X.

update_ball_state :-
    ball_state(PosX, PosY, VelX, VelY),
    player1(Paddle1, Score1),
    player2(Paddle2, Score2),
    get_term_size(MaxWidth, MaxHeight),
    NewY is max(0, min(PosY + VelY, MaxHeight)),
    NewX is max(0, min(PosX + VelX, MaxWidth)),
    ((VelX > 0, NewX =:= MaxWidth-2) ->
        ((NewY >= Paddle2, NewY < Paddle2+7) ->
            abs(VelX, AbsVelX),
            NewVelX is -AbsVelX,
            NewScore1 is Score1,
            NewScore2 is Score2;
            NewScore1 is Score1 + 1,
            NewScore2 is Score2,
            abs(VelX, AbsVelX),
            NewVelX is -AbsVelX
        ) ;
    (VelX < 0, NewX =:= 1) -> 
        ((NewY >= Paddle1, NewY < Paddle1+7) ->
            abs(VelX, AbsVelX),
            NewVelX is AbsVelX,
            NewScore1 is Score1,
            NewScore2 is Score2;
            NewScore2 is Score2 + 1,
            NewScore1 is Score1,
            abs(VelX, AbsVelX),
            NewVelX is AbsVelX
        ) ;
        NewScore1 is Score1,
        NewScore2 is Score2,
        NewVelX is VelX
    ),
    ((NewY >= MaxHeight) ->
        abs(VelY, AbsVelY),
        NewVelY is -AbsVelY; 
    (NewY =< 1) ->
        abs(VelY, AbsVelY),
        NewVelY is AbsVelY; 
        NewVelY is VelY
    ),
    retractall(ball_state(_, _, _, _)),
    assertz(ball_state(NewX, NewY, NewVelX, NewVelY)),
    retractall(player1(_, _)),
    assertz(player1(Paddle1, NewScore1)),
    retractall(player2(_, _)),
    assertz(player2(Paddle2, NewScore2)).

draw_paddle(_, _, 0, _).

draw_paddle(X, Y, Length, Char) :-
    Length > 0,
    char_at(X, Y, Char),
    Y1 is Y + 1,
    Length1 is Length - 1,
    draw_paddle(X, Y1, Length1, Char).

integer_to_string(Int, Str) :-
    atom_number(Atom, Int),
    atom_concat(Atom, '', Str).

draw_score(Score1, Score2) :-
    get_term_size(Width, _),
    integer_to_string(Score1, Score1Str),
    char_at(Width/2 - 3, 1, Score1Str),
    integer_to_string(Score2, Score2Str),
    char_at(Width/2 + 3, 1, Score2Str),
    char_at(Width/2, 1, '|').

main_loop :-
    repeat,
    get_term_size(Width, _),

    ball_state(OldPosX, OldPosY, _, _),

    update_ball_state,

    ball_state(PosX, PosY, _, _),
    char_at(PosX, PosY, '@'),
    char_at(OldPosX, OldPosY, ' '),

    player1(Paddle1, Score1),
    draw_paddle(1, Paddle1, 7, '#'),

    player2(Paddle2, Score2),
    draw_paddle(Width-2, Paddle2, 7, '#'),

    draw_score(Score1, Score2),

    sleep(0.01),
    flush_output,

    input_char(Char),
    (Char =:= 113 -> % q
        ! 
    ;(Char =:= 119 -> % w
        retractall(player1(_, _)),
        draw_paddle(1, Paddle1, 7, ' '),
        assertz(player1(Paddle1-2, Score1))
    ;Char =:= 115 -> % s
        retractall(player1(_, _)),
        draw_paddle(1, Paddle1, 7, ' '),
        assertz(player1(Paddle1+2, Score1))
    ;Char =:= 107 -> % k
        retractall(player2(_, _)),
        draw_paddle(Width-2, Paddle2, 7, ' '),
        assertz(player2(Paddle2-2, Score2))
    ;Char =:= 106 -> % j
        retractall(player2(_, _)),
        draw_paddle(Width-2, Paddle2, 7, ' '),
        assertz(player2(Paddle2+2, Score2))
    ), 
    retractall(input_char(_)),
    assertz(input_char(1)),
    fail).

input_loop :-
    repeat,
    get_single_char(Char),
    retractall(input_char(_)),
    assertz(input_char(Char)),
    (input_char(Char), Char =:= 113 -> % q
        !
    ; fail).

main :-
    enable_raw_mode,
    enter_alt_screen,
    hide_cursor,
    initial_state,
    thread_create(input_loop, _, [detached(true)]), 
    catch(main_loop, _, true),
    show_cursor,
    exit_alt_screen,
    disable_raw_mode.

:- main.
