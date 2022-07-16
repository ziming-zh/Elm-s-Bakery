module Update exposing (update)
import Array
import Message exposing (Msg(..), stepTime,Direction)
import Model exposing (Model,updateGridsfromModel,getModel)
import Wall exposing (Wall, isWall)
import Player exposing (State(..),Player)
import Valve exposing (pushDown,pushLeft,pushUp,pushRight,Valve)
import Grid exposing (getGstate,sendPainttoGrids,getGrid)
import Grid exposing (IsOpen)
import Grid exposing (IsOpen(..),Grids,movePaint)
import DBFS exposing (bfs)
import Message exposing (Paint)
import Color
import Model exposing (loadValves,getModel)
import Grid exposing (getDistance)
-- import Grid exposing (clearPaintGrid)
import Player exposing (State(..))
import Message exposing (Page(..))
import Message exposing (Pos)
--import Valve exposing(push,isValve)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick elapsed ->
            ( { model
                | move_timer = model.move_timer + elapsed
              }
                |> timedForward
            , Cmd.none
            )

        ArrowPressed dir ->
            ({ model| player = Player.changeDir model.player dir
            }, Cmd.none
            )

        GetViewport { viewport } ->
            ( { model
                | windowsize =
                    ( viewport.width
                    , viewport.height
                    )
              }
            , Cmd.none ) 

        Resize width height ->
            ( { model | windowsize = ( toFloat width, toFloat height ) }
            , Cmd.none
            )

        LoadNextLevel ->
            case model.currentPage of
                GuidePage ->
                    if Basics.modBy 2 model.level_index == 0  then
                        let
                            index = model.level_index + 1
                            (nmodel,nmsg) = getModel (round ((toFloat (model.level_index+1))/2)) model 
                        in
                            ( { nmodel | currentPage = GuidePage , level_index = index } , nmsg )
                        
                    else
                        ( { model | level_index = model.level_index + 1 , move_timer = 0 } , Cmd.none )
                HomePage -> 
                    ( { model | currentPage = ChoicePage } , Cmd.none )
                LevelsPage ->
                    ( { model | currentPage = GamePage } , Cmd.none )
                GamePage -> 
                    ( { model | currentPage = LevelsPage } , Cmd.none )
                _ -> 
                    ( model , Cmd.none )

        LoadLevel k ->
            getModel k model

        Load page ->
            ( { model | currentPage = page , move_timer = 0 , level_index = 0 } , Cmd.none )

        _ ->
            ( model, Cmd.none )


move : Model -> Model
move model =
    let
        (player,valves) =
            case getGstate model.player.pos model.updatedGrids model.player.dir of 
                Open ->
                    (Player.move model.player,model.valves)
                FakeClose ->
                    (Player.move model.player,pushValve model.player model.valves )
                Close ->
                    (model.player,model.valves)
        
        newmodel={ model | player = { player | state = Stopped }, valves = valves }
        newgrids=loadValves newmodel.grids newmodel.valves

        (nmodel,npaints) = movePaints (newmodel, model.paints) (newgrids |> bfs model.exit)
        newnewmodel={nmodel|paints=npaints}
    in
        {newnewmodel|updatedGrids = (updateGridsfromModel newnewmodel newmodel.grids)|>bfs model.exit  }

posequal : Pos -> Pos -> Bool
posequal pos1 pos2 =
    pos1.x == pos2.x && pos1.y == pos2.y

movePaintsRecur : (Model, List Paint) -> Grids -> Int -> (Model,List Paint)
movePaintsRecur (model,paints) grids  i =
    let
        l=List.length paints
        arrPaints=Array.fromList paints
    in
        if i<l then
            let 
                newPaints = Array.toList ( Grid.movePaint grids i arrPaints )
                newGrid = bfs model.exit (loadValves model.grids model.valves)
                newnewGrid = (List.foldl sendPainttoGrids newGrid newPaints)
            in
                movePaintsRecur (model, newPaints) newnewGrid  (i+1)
        else 
            let
                exitpaint=Tuple.first (List.partition (\x -> (posequal x.pos model.exit.pos)) paints)
                normalpaint = Tuple.second (List.partition (\x -> (posequal x.pos model.exit.pos)) paints)
                mcolorseq = model.mcolor_seq ++ List.map (\x -> x.color) exitpaint
            in
                ({model|mcolor_seq = mcolorseq}, List.sortBy (\x -> getDistance x.pos grids) normalpaint)
        
movePaints : (Model, List Paint) -> Grids ->(Model, List Paint)
movePaints (model,paints) grids  =
    let
        sorted = List.sortBy  (\x -> getDistance x.pos grids) paints
    in
        movePaintsRecur (model,sorted) grids  0
    

timedForward : Model -> Model
timedForward model =
    if model.currentPage == GuidePage && ( Basics.modBy 2 model.level_index == 0 ) then model
    else
    if model.move_timer > stepTime then
        let
            newModel =
                move model
        in
        { newModel | move_timer = 0 }

    else
        model
pushValve : Player -> List Valve -> List Valve
pushValve player valves =
    let
        x =
            player.pos.x

        y =
            player.pos.y

        dir =
            player.dir

        pos =
            player.pos

        newvalves =
            case dir of
                Message.Up ->
                    pushUp valves pos

                Message.Down ->
                    pushDown valves pos

                Message.Left ->
                    pushLeft valves pos

                Message.Right ->
                    pushRight valves pos

                Message.Stop ->
                    valves
    in
    newvalves