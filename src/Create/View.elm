module Create.View exposing (root)

import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Contracts.Types as CTypes
import Create.Types exposing (..)
import Currencies
import Element exposing (Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Element.Input
import FormatFloat exposing (formatFloat)
import Helpers.Element as EH
import Helpers.Eth as EthHelpers
import Helpers.Tuple as TupleHelpers
import Images
import Maybe.Extra
import Routing
import TokenValue exposing (TokenValue)
import Wallet


root : Model -> ( Element Msg, List (Element Msg) )
root model =
    ( EH.simpleSubmodelContainer
        800
        (Element.column
            [ Element.width Element.fill
            , Element.spacing 20
            ]
            [ header model.mode
            , EH.thinGrayHRuler
            , body model
            ]
        )
    , viewModals model
    )


header : Mode -> Element Msg
header mode =
    let
        descriptionText =
            case mode of
                CryptoSwap _ ->
                    "Please choose which two cryptocurrencies you’d like to exchange, indicate which wallet address you’d like your exchanged coins sent, and edit the three trade windows if necessary."

                OffRamp ->
                    "You are the seller. Choose what cryptocurrency/fiat you wish to exchange, what payment methods you are willing to accept from the buyer, and edit the three trade windows if necessary."

                OnRamp ->
                    "You are the buyer. Choose what cryptocurrency/fiat you wish to exchange, what payment methods you are willing to send to the seller, and edit the three trade windows if necessary."
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 20
        , Element.padding 30
        ]
        [ Element.row
            [ Element.spacing 40
            , Element.centerX
            ]
            [ modeHeader (mode == CryptoSwap Seller || mode == CryptoSwap Buyer) (CryptoSwap Seller)
            , modeHeader (mode == OffRamp) OffRamp
            , modeHeader (mode == OnRamp) OnRamp
            ]
        , Element.paragraph
            [ Element.Font.size 16 ]
            [ Element.text descriptionText ]
        ]


modeHeader : Bool -> Mode -> Element Msg
modeHeader selected mode =
    let
        fontAlpha =
            if selected then
                1.0

            else
                0.15

        text =
            case mode of
                CryptoSwap _ ->
                    "CryptoSwap"

                OffRamp ->
                    "Off Ramp"

                OnRamp ->
                    "???"
    in
    Element.el
        [ Element.Font.size 28
        , Element.Font.semiBold
        , Element.Font.color <| Element.rgba 0 0 0 fontAlpha
        , Element.pointer
        , Element.Events.onClick <| ChangeMode mode
        ]
        (Element.text text)


body : Model -> Element Msg
body model =
    Element.column
        [ Element.width Element.fill
        , Element.padding 20
        , Element.spacing 25
        ]
        [ amountAndTypeIn model
        , case model.mode of
            CryptoSwap _ ->
                Element.el [ Element.centerX ] swapButton

            _ ->
                Element.none
        , amountOutRow model
        , moreInfoInput model
        , intervalsRow model
        , placeOrderButton model
        ]


amountAndTypeIn : Model -> Element Msg
amountAndTypeIn model =
    EH.withInputHeaderAndMaybeError
        [ Element.width Element.fill ]
        "I want to Sell"
        model.errors.amountIn
        (inputContainer
            [ Element.width Element.fill ]
            [ Element.Input.text
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Border.width 0
                ]
                { onChange = AmountInChanged
                , text = model.inputs.amountIn
                , placeholder =
                    Just <|
                        Element.Input.placeholder
                            [ Element.Font.color EH.placeholderTextColor ]
                            (Element.text "0")
                , label = Element.Input.labelHidden "amount in"
                }
            , Element.el
                ([ Element.height Element.fill ]
                    ++ (if model.showInTypeDropdown then
                            [ Element.below
                                (inTypeDropdown model)
                            ]

                        else
                            []
                       )
                )
                (typeDropdownButton
                    model.showInTypeDropdown
                    model.inputs.inType
                    InTypeClicked
                )
            ]
        )


swapButton : Element Msg
swapButton =
    EH.elOnCircle
        [ Element.pointer
        , Element.Events.onClick SwapClicked
        ]
        52
        (Element.rgba 0.05 0.03 0.92 0.05)
        (Images.toElement
            [ Element.height <| Element.px 30 ]
            Images.verticalSwapArrows
        )


amountOutRow : Model -> Element Msg
amountOutRow model =
    Element.row
        [ Element.width Element.fill
        , Element.spacing 25
        ]
        [ Element.el [ Element.width <| Element.fillPortion 2 ]
            (amountAndTypeOut model)
        , Element.el
            [ Element.Font.size 28
            , Element.Font.color <| Element.rgba 0.05 0.1 0.3 0.25
            , Element.Font.semiBold
            , Element.alignBottom
            , Element.paddingEach
                { bottom = 14
                , top = 0
                , right = 0
                , left = 0
                }
            ]
            (Element.text "@")
        , Element.el
            [ Element.width <| Element.fillPortion 1
            , Element.above
                (if model.showMarginModal then
                    marginModal model.margin model.inputs.margin model.errors.margin

                 else
                    Element.none
                )
            ]
            (marginBox model)
        ]


moreInfoInput : Model -> Element Msg
moreInfoInput model =
    case model.mode of
        CryptoSwap Seller ->
            case model.inputs.outType of
                External cryptoSymbol ->
                    cryptoAddressInput cryptoSymbol model.inputs.receiveAddress

                _ ->
                    let
                        _ =
                            Debug.log "Unexpected currency type for outType!" model.inputs.outType
                    in
                    Element.none

        CryptoSwap Buyer ->
            Element.none

        OffRamp ->
            paymentMethodInput Seller model.inputs.paymentMethod

        OnRamp ->
            paymentMethodInput Buyer model.inputs.paymentMethod


amountAndTypeOut : Model -> Element Msg
amountAndTypeOut model =
    EH.withInputHeaderAndMaybeError
        [ Element.width Element.fill ]
        "In Exchange for"
        model.errors.amountOut
        (inputContainer
            [ Element.width Element.fill ]
            [ Element.Input.text
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Border.width 0
                ]
                { onChange = AmountOutChanged
                , text = model.inputs.amountOut
                , placeholder =
                    Just <|
                        Element.Input.placeholder
                            [ Element.Font.color EH.placeholderTextColor ]
                            (Element.text "0")
                , label = Element.Input.labelHidden "amount out"
                }
            , Element.el
                ([ Element.height Element.fill ]
                    ++ (if model.showOutTypeDropdown then
                            [ Element.below
                                (outTypeDropdown model)
                            ]

                        else
                            []
                       )
                )
                (typeDropdownButton
                    model.showOutTypeDropdown
                    model.inputs.outType
                    OutTypeClicked
                )
            ]
        )


marginBox : Model -> Element Msg
marginBox model =
    EH.withInputHeader
        [ Element.width Element.fill ]
        "Margin"
        (inputContainer
            [ Element.width Element.fill
            , Element.pointer
            , EH.onClickNoPropagation MarginBoxClicked
            ]
            [ Element.row
                [ Element.height Element.fill
                , Element.width Element.fill
                , Element.Background.color EH.white
                , Element.spacing 13
                ]
                [ profitLossOrEven model.margin
                , absMarginPercentage model.margin
                ]
            , dropdownArrow model.showMarginModal
            ]
        )


marginModal : Float -> String -> Maybe String -> Element Msg
marginModal margin marginInput maybeError =
    EH.modal
        (Element.rgba 0 0 0 0.1)
        NoOp
        CloseModals
    <|
        Element.column
            [ Element.alignRight
            , Element.moveUp 10
            , Element.Border.rounded 8
            , Element.Background.color EH.lightGray
            , Element.clip
            , Element.spacing 1
            , Element.Border.shadow
                { offset = ( 0, 3 )
                , size = 0
                , blur = 20
                , color = Element.rgba 0 0 0 0.08
                }
            ]
            [ Element.el
                [ Element.paddingXY 23 18
                , Element.Background.color EH.white
                ]
              <|
                Element.column
                    [ Element.width Element.fill
                    , Element.spacing 10
                    ]
                    [ Element.el
                        [ Element.Font.size 20
                        , Element.Font.semiBold
                        , Element.Font.color <| Element.rgb255 16 7 234
                        ]
                        (Element.text "Margin")
                    , Element.paragraph
                        [ Element.Font.size 16
                        , Element.Font.color <| Element.rgba 0 0 0 0.75
                        ]
                        [ Element.text "This is how much you want to either make as a profit or loss from this trade. Choose ‘loss’ if you’re looking to find a buyer fast. Choose ‘Even’ to set the margin to 0%." ]
                    ]
            , let
                inactiveBgColor =
                    Element.rgba255 10 33 108 0.04

                inactiveTextColor =
                    Element.rgb255 10 33 108
              in
              Element.row
                [ Element.width Element.shrink
                , Element.Background.color EH.white
                , Element.paddingXY 23 18
                , Element.spacing 12
                ]
                [ inputContainer
                    [ Element.width <| Element.px 140
                    , Element.above <|
                        case maybeError of
                            Just error ->
                                Element.el
                                    [ Element.Font.size 12
                                    , Element.Font.color EH.red
                                    , Element.moveUp 16
                                    , Element.alignLeft
                                    , Element.Background.color EH.white
                                    , Element.Border.widthEach
                                        { top = 0
                                        , bottom = 0
                                        , right = 1
                                        , left = 1
                                        }
                                    , Element.paddingXY 5 0
                                    , Element.Border.color EH.lightGray
                                    ]
                                    (Element.text error)

                            Nothing ->
                                Element.none
                    ]
                    [ Element.Input.text
                        [ Element.Border.width 0
                        , Element.width Element.fill
                        , Element.height Element.fill
                        ]
                        { onChange = MarginInputChanged
                        , text = marginInput ++ "%"
                        , placeholder = Nothing
                        , label = Element.Input.labelHidden "margin"
                        }
                    ]
                , if margin < 0 then
                    button
                        (Element.rgb255 255 0 118)
                        EH.white
                        "Loss"
                        Nothing

                  else
                    button
                        inactiveBgColor
                        inactiveTextColor
                        "Loss"
                        (Just <| MarginButtonClicked Loss)
                , if margin == 0 then
                    button
                        (Element.rgb255 16 7 234)
                        EH.white
                        "Even"
                        Nothing

                  else
                    button
                        inactiveBgColor
                        inactiveTextColor
                        "Even"
                        (Just <| MarginButtonClicked Even)
                , if margin > 0 then
                    button
                        (Element.rgb255 0 188 137)
                        EH.white
                        "Profit"
                        Nothing

                  else
                    button
                        inactiveBgColor
                        inactiveTextColor
                        "Profit"
                        (Just <| MarginButtonClicked Profit)
                ]
            ]


button : Element.Color -> Element.Color -> String -> Maybe Msg -> Element Msg
button bgColor textColor text maybeOnClick =
    Element.el
        ([ Element.Background.color bgColor
         , Element.Border.rounded 4
         , Element.paddingXY 22 16
         , Element.Font.color textColor
         , Element.Font.size 20
         ]
            ++ (case maybeOnClick of
                    Just onClick ->
                        [ Element.pointer
                        , Element.Events.onClick onClick
                        ]

                    Nothing ->
                        []
               )
        )
        (Element.text text)


profitLossOrEven : Float -> Element Msg
profitLossOrEven margin =
    let
        ( text, bgColor, textColor ) =
            if margin == 0 then
                ( "Even"
                , Element.rgba255 16 7 234 0.05
                , Element.rgb255 16 7 234
                )

            else if margin > 0 then
                ( "Profit"
                , Element.rgba255 0 188 137 0.05
                , Element.rgb255 0 188 137
                )

            else
                ( "Loss"
                , Element.rgba255 255 0 118 0.05
                , Element.rgb255 255 0 118
                )
    in
    Element.el
        [ Element.padding 7 ]
    <|
        Element.el
            [ Element.paddingXY 15 9
            , Element.Background.color bgColor
            , Element.Border.rounded 4
            , Element.Font.color textColor
            , Element.Font.size 20
            , Element.Font.semiBold
            ]
            (Element.text text)


absMarginPercentage : Float -> Element Msg
absMarginPercentage margin =
    Element.el
        [ Element.Font.size 20
        , Element.Font.semiBold
        ]
        (Element.text
            (((margin * 100)
                |> abs
                |> formatFloat 2
             )
                ++ "%"
            )
        )


inTypeDropdown : Model -> Element Msg
inTypeDropdown model =
    case model.mode of
        CryptoSwap Seller ->
            dhTokenTypeDropdown
                (InTypeSelected << DHToken)

        OffRamp ->
            dhTokenTypeDropdown
                (InTypeSelected << DHToken)

        CryptoSwap Buyer ->
            cryptoTypeDropdown
                model.inputs.currencySearch
                SearchInputChanged
                (InTypeSelected << External)

        OnRamp ->
            fiatTypeDropdown
                model.inputs.currencySearch
                SearchInputChanged
                (InTypeSelected << External)


outTypeDropdown : Model -> Element Msg
outTypeDropdown model =
    case model.mode of
        CryptoSwap Seller ->
            cryptoTypeDropdown
                model.inputs.currencySearch
                SearchInputChanged
                (OutTypeSelected << External)

        CryptoSwap Buyer ->
            dhTokenTypeDropdown
                (OutTypeSelected << DHToken)

        OffRamp ->
            fiatTypeDropdown
                model.inputs.currencySearch
                SearchInputChanged
                (OutTypeSelected << External)

        OnRamp ->
            dhTokenTypeDropdown
                (OutTypeSelected << DHToken)


dhTokenTypeDropdown : (FactoryType -> Msg) -> Element Msg
dhTokenTypeDropdown msgConstructor =
    EH.modal
        (Element.rgba 0 0 0 0.1)
        NoOp
        CloseModals
    <|
        EH.basicOpenDropdown
            [ Element.width <| Element.px 300
            , Element.moveDown 10
            , Element.alignRight
            ]
            Nothing
            (dhTokenList
                |> List.map
                    (\tokenType ->
                        ( Element.row
                            [ Element.width Element.fill
                            , Element.spacing 18
                            ]
                            (Maybe.Extra.values
                                [ Currencies.icon <| tokenSymbol tokenType
                                , Just <| Element.text <| tokenUnitName tokenType
                                ]
                            )
                        , msgConstructor tokenType
                        )
                    )
            )


cryptoTypeDropdown : String -> (String -> Msg) -> (Currencies.Symbol -> Msg) -> Element Msg
cryptoTypeDropdown searchInput searchChangedMsg selectedMsg =
    EH.modal
        (Element.rgba 0 0 0 0.1)
        NoOp
        CloseModals
    <|
        EH.searchableOpenDropdown
            [ Element.width <| Element.px 300
            , Element.moveDown 18
            , Element.alignRight
            ]
            "search cryptocurrencies"
            (Currencies.foreignCryptoList
                |> List.map
                    (\symbol ->
                        ( Element.row
                            [ Element.width Element.fill
                            , Element.spacing 18
                            ]
                            (Maybe.Extra.values
                                [ Currencies.icon symbol
                                , Just <| Element.text symbol
                                ]
                            )
                        , [ symbol ]
                        , selectedMsg symbol
                        )
                    )
            )
            searchInput
            searchChangedMsg


fiatTypeDropdown : String -> (String -> Msg) -> (Currencies.Symbol -> Msg) -> Element Msg
fiatTypeDropdown searchInput searchChangedMsg selectedMsg =
    EH.modal
        (Element.rgba 0 0 0 0.1)
        NoOp
        CloseModals
    <|
        EH.searchableOpenDropdown
            [ Element.width <| Element.px 300
            , Element.moveDown 18
            , Element.alignRight
            ]
            "search currencies"
            (Currencies.fiatList
                |> List.map
                    (\fiatSymbol ->
                        ( Element.row
                            [ Element.width Element.fill
                            , Element.spacing 18
                            ]
                            (Maybe.Extra.values
                                [ Currencies.icon fiatSymbol
                                , Just <| Element.text fiatSymbol
                                ]
                            )
                        , Maybe.Extra.values [ Just fiatSymbol, Currencies.fiatChar fiatSymbol ]
                        , selectedMsg fiatSymbol
                        )
                    )
            )
            searchInput
            searchChangedMsg


typeDropdownButton : Bool -> CurrencyType -> Msg -> Element Msg
typeDropdownButton dropdownOpen currencyType onClick =
    Element.row
        [ Element.Background.color <| Element.rgb 0.98 0.98 0.98
        , Element.height Element.fill
        , Element.padding 13
        , Element.spacing 13
        , Element.pointer
        , EH.onClickNoPropagation onClick
        ]
        [ Currencies.icon (currencySymbol currencyType)
            |> Maybe.withDefault Element.none
        , Element.text <| currencySymbol currencyType
        , Images.toElement
            [ Element.width <| Element.px 12 ]
          <|
            if dropdownOpen then
                Images.upArrow

            else
                Images.downArrow
        ]


cryptoAddressInput : Currencies.Symbol -> String -> Element Msg
cryptoAddressInput symbol input =
    EH.withInputHeader
        [ Element.width Element.fill ]
        (symbol ++ " Receive Address")
    <|
        inputContainer
            [ Element.width Element.fill
            ]
            [ Element.Input.text
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Border.width 0
                ]
                { onChange = ReceiveAddressChanged
                , text = input
                , placeholder = Nothing
                , label = Element.Input.labelHidden "receive address"
                }
            ]


paymentMethodInput : BuyerOrSeller -> String -> Element Msg
paymentMethodInput initiatorRole input =
    EH.withInputHeader
        [ Element.width Element.fill ]
        (case initiatorRole of
            Buyer ->
                "Making the Payment"

            Seller ->
                "Accepting the Payment"
        )
    <|
        inputContainer
            [ Element.height <| Element.px 134
            , Element.width Element.fill
            ]
            [ Element.Input.multiline
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Border.width 0
                , Element.scrollbarY
                ]
                { onChange = PaymentMethodChanged
                , text = input
                , placeholder =
                    Just <|
                        Element.Input.placeholder
                            [ Element.Font.color EH.placeholderTextColor ]
                        <|
                            Element.column [ Element.spacing 20 ] <|
                                case initiatorRole of
                                    Buyer ->
                                        [ Element.text "Indicate here how you will send payment to the seller."
                                        , Element.text "Eg. National bank transfer (UK only) or cash in person (London only)"
                                        ]

                                    Seller ->
                                        [ Element.text "Indicate here how you will accept payment from the buyer."
                                        , Element.text "Eg. National bank transfer (UK only) or cash in person (London only)"
                                        ]
                , label = Element.Input.labelHidden "payment method"
                , spellcheck = True
                }
            ]


intervalsRow : Model -> Element Msg
intervalsRow model =
    Element.row
        [ Element.width Element.fill
        , Element.spacing 23
        ]
        [ phaseWindowBoxAndMaybeModal Expiry model
        , phaseWindowBoxAndMaybeModal Payment model
        , phaseWindowBoxAndMaybeModal Judgment model
        ]


phaseWindowBoxAndMaybeModal : IntervalType -> Model -> Element Msg
phaseWindowBoxAndMaybeModal intervalType model =
    let
        showModal =
            model.showIntervalModal == Just intervalType
    in
    Element.el
        [ Element.width Element.fill
        , Element.above <|
            if showModal then
                intervalModal
                    intervalType
                    (getUserInterval intervalType model)
                    model.inputs.interval
                    model.errors.interval

            else
                Element.none
        ]
    <|
        phaseWindowBox
            intervalType
            (getUserInterval intervalType model)
            showModal


phaseWindowBox : IntervalType -> UserInterval -> Bool -> Element Msg
phaseWindowBox intervalType interval modalIsOpen =
    EH.withInputHeader
        [ Element.width Element.fill ]
        (case intervalType of
            Expiry ->
                "Offer Expiry"

            Payment ->
                "Payment Due"

            Judgment ->
                "Burn Window"
        )
    <|
        inputContainer
            [ Element.width Element.fill
            , Element.pointer
            , EH.onClickNoPropagation (WindowBoxClicked intervalType)
            ]
            [ Element.el
                [ Element.height Element.fill
                , Element.width Element.fill
                , Element.Background.color EH.white
                , Element.paddingXY 15 17
                ]
                (userInterval interval)
            , dropdownArrow modalIsOpen
            ]


userInterval : UserInterval -> Element Msg
userInterval interval =
    Element.el
        [ Element.Font.size 20
        , Element.Font.medium
        ]
    <|
        Element.text <|
            String.fromInt interval.num
                ++ " "
                ++ intervalUnitToString interval.unit
                ++ (if interval.num == 1 then
                        ""

                    else
                        "s"
                   )


intervalModal : IntervalType -> UserInterval -> String -> Maybe String -> Element Msg
intervalModal intervalType value input maybeError =
    let
        ( title, text ) =
            case intervalType of
                Expiry ->
                    ( "Offer Expiry"
                    , "This is the window of time that your trade will be available in the marketplace for someone to claim. You can recall this trade at anytime during this window given that it hasn’t yet been claimed."
                    )

                Payment ->
                    ( "Payment Due"
                    , "This is the window of time that the responder of this trade will have to confirm that they have successfully sent the exchange amount to your specified wallet."
                    )

                Judgment ->
                    ( "Burn Window"
                    , "During this window, you have to decide if the responder has indeed sent the exchange amount to you and thus decide to burn or release the trade. If there is no action from you before this window expires, the trade will be auto-released."
                    )
    in
    EH.modal
        (Element.rgba 0 0 0 0.1)
        NoOp
        CloseModals
    <|
        Element.column
            [ Element.moveUp 10
            , Element.Border.rounded 8
            , Element.Background.color EH.lightGray
            , Element.spacing 1
            , Element.clip
            , Element.Border.shadow
                { offset = ( 0, 3 )
                , size = 0
                , blur = 20
                , color = Element.rgba 0 0 0 0.08
                }
            , if intervalType == Judgment then
                Element.alignRight

              else
                Element.alignLeft
            ]
            [ Element.el
                [ Element.paddingXY 23 18
                , Element.Background.color EH.white
                , Element.width Element.fill
                ]
              <|
                Element.column
                    [ Element.width Element.fill
                    , Element.spacing 10
                    ]
                    [ Element.el
                        [ Element.Font.size 20
                        , Element.Font.semiBold
                        , Element.Font.color <| Element.rgb255 16 7 234
                        ]
                        (Element.text title)
                    , Element.paragraph
                        [ Element.Font.size 16
                        , Element.Font.color <| Element.rgba 0 0 0 0.75
                        ]
                        [ Element.text text ]
                    ]
            , let
                timeUnitButton : IntervalUnit -> Bool -> Element Msg
                timeUnitButton unit selected =
                    button
                        (if selected then
                            Element.rgb255 16 7 234

                         else
                            Element.rgba255 10 33 108 0.04
                        )
                        (if selected then
                            EH.white

                         else
                            Element.rgb255 10 33 108
                        )
                        (intervalUnitToString unit
                            ++ "s"
                            |> String.toLower
                        )
                        (if selected then
                            Nothing

                         else
                            Just <|
                                IntervalUnitChanged unit
                        )
              in
              Element.row
                [ Element.paddingXY 23 18
                , Element.Background.color EH.white
                , Element.spacing 12
                ]
                [ inputContainer
                    [ Element.width <| Element.px 140
                    , Element.above <|
                        case maybeError of
                            Just error ->
                                Element.el
                                    [ Element.Font.size 12
                                    , Element.Font.color EH.red
                                    , Element.moveUp 16
                                    , Element.alignLeft
                                    , Element.Background.color EH.white
                                    , Element.Border.widthEach
                                        { top = 0
                                        , bottom = 0
                                        , right = 1
                                        , left = 1
                                        }
                                    , Element.paddingXY 5 0
                                    , Element.Border.color EH.lightGray
                                    ]
                                    (Element.text error)

                            Nothing ->
                                Element.none
                    ]
                    [ Element.Input.text
                        [ Element.Border.width 0
                        , Element.width Element.fill
                        , Element.height Element.fill
                        ]
                        { onChange = IntervalInputChanged
                        , text = input
                        , placeholder = Nothing
                        , label = Element.Input.labelHidden (title ++ " input")
                        }
                    ]
                , timeUnitButton Minute (value.unit == Minute)
                , timeUnitButton Hour (value.unit == Hour)
                , timeUnitButton Day (value.unit == Day)
                , timeUnitButton Week (value.unit == Week)
                ]
            ]


dropdownArrow : Bool -> Element Msg
dropdownArrow pointUp =
    Element.el
        [ Element.alignRight
        , Element.height Element.fill
        , Element.Background.color <| Element.rgb 0.98 0.98 0.98
        , Element.padding 13
        ]
    <|
        Images.toElement
            [ Element.centerY ]
            (if pointUp then
                Images.upArrow

             else
                Images.downArrow
            )


inputContainer : List (Element.Attribute Msg) -> List (Element Msg) -> Element Msg
inputContainer attributes =
    Element.row <|
        [ Element.Background.color EH.lightGray
        , Element.height <| Element.px 55
        , Element.Border.rounded 4
        , Element.Border.width 1
        , Element.Border.color EH.lightGray
        , Element.spacing 1
        ]
            ++ attributes


placeOrderButton : Model -> Element Msg
placeOrderButton model =
    let
        buttonBuilder bgColor textColor text maybeOnClick maybeError =
            Element.el
                ([ Element.width Element.fill
                 , Element.padding 17
                 , Element.Border.rounded 4
                 , Element.Font.size 20
                 , Element.Font.semiBold
                 , Element.Font.center
                 , Element.Background.color bgColor
                 , Element.Font.color textColor
                 , Element.above <|
                    case maybeError of
                        Just error ->
                            Element.el
                                [ Element.Font.size 12
                                , Element.Font.color EH.red
                                , Element.moveUp 16
                                , Element.centerX
                                ]
                                (Element.text error)

                        Nothing ->
                            Element.none
                 ]
                    ++ (case maybeOnClick of
                            Just onClick ->
                                [ Element.pointer
                                , Element.Events.onClick onClick
                                ]

                            Nothing ->
                                []
                       )
                )
                (Element.text text)
    in
    case ( Wallet.userInfo model.wallet, maybeUserParameters model ) of
        ( Just userInfo, Just userParameters ) ->
            if Wallet.factory model.wallet == Just model.dhTokenType then
                buttonBuilder
                    (Element.rgb255 255 0 110)
                    EH.white
                    "Place Order"
                    (Just <| PlaceOrderClicked model.dhTokenType userInfo userParameters)
                    Nothing

            else
                buttonBuilder
                    EH.lightGray
                    EH.black
                    "Place Order"
                    Nothing
                    (Just <|
                        "You must switch your wallet to the "
                            ++ networkNameForFactory model.dhTokenType
                            ++ " network to create a trade with "
                            ++ tokenUnitName model.dhTokenType
                    )

        ( Nothing, _ ) ->
            buttonBuilder
                EH.red
                EH.white
                "Connect to Wallet"
                (Just <| CmdUp CmdUp.Web3Connect)
                Nothing

        ( _, Nothing ) ->
            buttonBuilder
                EH.lightGray
                EH.black
                "Place Order"
                Nothing
                Nothing


txChainStatusModal : TxChainStatus -> Model -> Element Msg
txChainStatusModal txChainStatus model =
    case txChainStatus of
        Confirm factoryType createParameters ->
            let
                ( depositAmountEl, totalBurnableEl, confirmButton ) =
                    case model.depositAmount of
                        Just depositAmount ->
                            let
                                depositAmountText =
                                    TokenValue.toConciseString depositAmount
                                        ++ " "
                                        ++ tokenUnitName factoryType

                                totalBurnableText =
                                    TokenValue.toConciseString
                                        (TokenValue.add
                                            depositAmount
                                            (CTypes.getResponderDeposit createParameters)
                                            |> TokenValue.add (CTypes.calculateDHFee createParameters)
                                        )
                                        ++ " "
                                        ++ tokenUnitName factoryType
                            in
                            ( blueText depositAmountText
                            , blueText totalBurnableText
                            , EH.redButton
                                ("Yes. Deposit "
                                    ++ depositAmountText
                                    ++ " and open this trade."
                                )
                                (ConfirmCreate factoryType createParameters depositAmount)
                            )

                        Nothing ->
                            ( blueText "??"
                            , blueText "??"
                            , EH.disabledButton "(loading exact fees...)" Nothing
                            )

                feeAmountEl =
                    blueText <|
                        TokenValue.toConciseString (CTypes.calculateDHFee createParameters)
                            ++ " "
                            ++ tokenUnitName factoryType

                tradeAmountEl =
                    blueText <|
                        TokenValue.toConciseString createParameters.tradeAmount
                            ++ " "
                            ++ tokenUnitName factoryType

                notYetButton =
                    EH.blueButton
                        "Not yet. Go back."
                        AbortCreate

                buyerDepositEl =
                    blueText <|
                        TokenValue.toConciseString createParameters.buyerDeposit
                            ++ " "
                            ++ tokenUnitName factoryType

                totalReleaseableEl =
                    blueText <|
                        TokenValue.toConciseString (TokenValue.add createParameters.tradeAmount createParameters.buyerDeposit)
                            ++ " "
                            ++ tokenUnitName factoryType

                expiryWindowEl =
                    emphasizedText <|
                        userIntervalToString <|
                            getUserInterval Expiry model

                paymentWindowEl =
                    emphasizedText <|
                        userIntervalToString <|
                            getUserInterval Payment model

                judgmentWindowEl =
                    emphasizedText <|
                        userIntervalToString <|
                            getUserInterval Judgment model

                priceEl =
                    blueText <| Currencies.toString createParameters.price

                emphasizedText =
                    Element.el
                        [ Element.Font.bold
                        , Element.Font.color EH.black
                        ]
                        << Element.text

                blueText =
                    Element.el
                        [ Element.Font.semiBold
                        , Element.Font.color EH.blue
                        ]
                        << Element.text
            in
            EH.closeableModal
                []
                (Element.column
                    [ Element.spacing 20
                    , Element.padding 20
                    , Element.centerX
                    , Element.height Element.fill
                    , Element.width Element.fill
                    , Element.Font.center
                    ]
                    [ Element.el
                        [ Element.Font.size 26
                        , Element.Font.semiBold
                        , Element.centerX
                        , Element.centerY
                        ]
                        (case createParameters.initiatorRole of
                            Buyer ->
                                Element.text "Opening a DAIHard Buy Offer"

                            Seller ->
                                Element.text "Opening a DAIHard Sell Offer"
                        )
                    , Element.column
                        [ Element.spacing 20
                        , Element.centerX
                        , Element.centerY
                        ]
                        (List.map
                            (Element.paragraph
                                [ Element.centerX
                                , Element.Font.size 18
                                , Element.Font.medium
                                , Element.Font.color EH.permanentTextColor
                                ]
                            )
                            (case createParameters.initiatorRole of
                                Buyer ->
                                    [ [ Element.text "To open this offer, you must deposit "
                                      , depositAmountEl
                                      , Element.text ". Your offer to buy "
                                      , tradeAmountEl
                                      , Element.text " for "
                                      , priceEl
                                      , Element.text " will then be listed on the marketplace."
                                      ]
                                    , [ Element.text "You can abort the offer any time before a Seller commits for a full refund. If no Seller commits within "
                                      , expiryWindowEl
                                      , Element.text " your offer will automatically expire. In both these cases, the full "
                                      , depositAmountEl
                                      , Element.text " is returned to you."
                                      ]
                                    , [ Element.text "A Seller can commit to the trade by depositing the full "
                                      , tradeAmountEl
                                      , Element.text " into the contract, and is expected to immediately post his "
                                      , blueText <| createParameters.price.symbol
                                      , Element.text " address in the DAIHard chat."
                                      ]
                                    , case model.mode of
                                        CryptoSwap _ ->
                                            [ Element.text "You will then have "
                                            , paymentWindowEl
                                            , Element.text " to send "
                                            , priceEl
                                            , Element.text " to that address and click \"Confirm Payment\"."
                                            ]

                                        _ ->
                                            [ Element.text "You are then expected to send "
                                            , priceEl
                                            , Element.text " and click \"Confirm Payment\" within "
                                            , paymentWindowEl
                                            , Element.text "."
                                            ]
                                    , [ Element.text "Once you've confirmed payment, for "
                                      , judgmentWindowEl
                                      , Element.text ", the Seller has the option of burning the trade's full balance of "
                                      , totalBurnableEl
                                      , Element.text ". He is expected to do this if and only if you failed to send the "
                                      , priceEl
                                      , Element.text " to the address he posted."
                                      ]
                                    , [ Element.text "If the Seller has not burned the "
                                      , Element.text <| tokenUnitName factoryType
                                      , Element.text " within the "
                                      , judgmentWindowEl
                                      , Element.text ", "
                                      , totalReleaseableEl
                                      , Element.text " is yours to claim and we take a 1% fee ("
                                      , feeAmountEl
                                      , Element.text ")."
                                      ]
                                    , [ Element.text <| "Are you ready?" ]
                                    ]
                                        ++ (case factoryType of
                                                Token _ ->
                                                    [ [ Element.text <| "(Trade creation ususally requires two Metamask signatures. Your " ++ tokenUnitName factoryType ++ " will not be deposited until the final transaction has been mined.)" ] ]

                                                Native _ ->
                                                    []
                                           )

                                Seller ->
                                    [ [ Element.text "Of your "
                                      , depositAmountEl
                                      , Element.text ", 1% ("
                                      , feeAmountEl
                                      , Element.text ") will be set aside, and "
                                      , tradeAmountEl
                                      , Element.text " will be listed as selling for "
                                      , priceEl
                                      , Element.text "."
                                      ]
                                    , [ Element.text "You can abort the offer at any time before a Buyer commits for a full refund. If no Buyer commits within "
                                      , expiryWindowEl
                                      , Element.text " your offer will automatically expire. In both these cases, the full "
                                      , depositAmountEl
                                      , Element.text " is returned to you."
                                      ]
                                    ]
                                        ++ (case model.mode of
                                                CryptoSwap _ ->
                                                    [ [ Element.text "A Buyer must deposit "
                                                      , buyerDepositEl
                                                      , Element.text <| " into this contract to commit. He is then expected to send the "
                                                      , priceEl
                                                      , Element.text <| " to your receive address "
                                                      , blueText model.inputs.receiveAddress
                                                      , Element.text ", and mark the payment as complete, all within "
                                                      , paymentWindowEl
                                                      ]
                                                    , [ emphasizedText "Make sure the above address is correct! DAIHard does not do refunds!" ]
                                                    ]

                                                _ ->
                                                    [ [ Element.text "A Buyer must deposit "
                                                      , buyerDepositEl
                                                      , Element.text <| " into this contract to commit. He is then expected to pay the "
                                                      , priceEl
                                                      , Element.text " to you, via the method you've descried in your "
                                                      , emphasizedText "Payment Methods"
                                                      , Element.text ", and mark the payment as complete, all within "
                                                      , paymentWindowEl
                                                      , Element.text "."
                                                      ]
                                                    ]
                                           )
                                        ++ [ [ Element.text <| "When the Buyer marks the payment complete, for "
                                             , judgmentWindowEl
                                             , Element.text " you will have the option to burn the trade's balance of "
                                             , totalBurnableEl
                                             , Element.text <| ", which you are expected to do if and only if the Buyer has not sent the payment."
                                             ]
                                           , [ Element.text "If the trade has resolved successfully, DAIHard takes the 1% fee of "
                                             , feeAmountEl
                                             , Element.text " set aside earlier."
                                             ]
                                           , [ Element.text <| "Are you ready?" ]
                                           ]
                                        ++ (case factoryType of
                                                Token _ ->
                                                    [ [ Element.text <| "(Trade creation ususally requires two Metamask signatures. Your " ++ tokenUnitName factoryType ++ " will not be deposited until the final transaction has been mined.)" ] ]

                                                Native _ ->
                                                    []
                                           )
                            )
                        )
                    , Element.column
                        [ Element.centerX
                        , Element.spacing 15
                        ]
                        ([ confirmButton
                         , notYetButton
                         ]
                            |> List.map (Element.el [ Element.centerX ])
                        )
                    ]
                )
                NoOp
                AbortCreate

        ApproveNeedsSig tokenType ->
            Element.el
                [ Element.centerX
                , Element.centerY
                , Element.Events.onClick <|
                    CmdUp <|
                        CmdUp.gTag "txChainModal clicked" "misclick" "ApproveNeedsSig" 0
                ]
            <|
                EH.txProcessModal
                    [ Element.text "Waiting for user signature for the approve call."
                    , Element.text "(check Metamask!)"
                    , Element.text "Note that there will be a second transaction to sign after this."
                    ]
                    NoOp
                    NoOp

        ApproveMining tokenType createParameters txHash ->
            Element.el
                [ Element.centerX
                , Element.centerY
                , Element.Events.onClick <|
                    CmdUp <|
                        CmdUp.gTag "txChainModal clicked" "misclick" "ApproveMining" 0
                ]
            <|
                EH.txProcessModal
                    [ Element.text "Mining the initial approve transaction..."
                    , Element.newTabLink [ Element.Font.underline, Element.Font.color EH.blue ]
                        { url = EthHelpers.makeViewTxUrl (Token tokenType) txHash
                        , label = Element.text "See the transaction on Etherscan"
                        }
                    , Element.text "Funds will not leave your wallet until you sign the next transaction."
                    ]
                    NoOp
                    NoOp

        CreateNeedsSig _ ->
            Element.el
                [ Element.centerX
                , Element.centerY
                , Element.Events.onClick <|
                    CmdUp <|
                        CmdUp.gTag "txChainModal clicked" "misclick" "CreateNeedsSig" 0
                ]
            <|
                EH.txProcessModal
                    [ Element.text "Waiting for user signature for the create call."
                    , Element.text "(check Metamask!)"
                    ]
                    NoOp
                    NoOp

        CreateMining factoryType txHash ->
            Element.el
                [ Element.centerX
                , Element.centerY
                , Element.Events.onClick <|
                    CmdUp <|
                        CmdUp.gTag "txChainModal clicked" "misclick" "CreateMining" 0
                ]
            <|
                EH.txProcessModal
                    [ Element.text "Mining the final create call..."
                    , Element.newTabLink [ Element.Font.underline, Element.Font.color EH.blue ]
                        { url = EthHelpers.makeViewTxUrl factoryType txHash
                        , label = Element.text "See the transaction on Etherscan"
                        }
                    , Element.text "You will be redirected when it's mined."
                    ]
                    NoOp
                    NoOp


viewModals : Model -> List (Element Msg)
viewModals model =
    case model.txChainStatus of
        Just txChainStatus ->
            [ txChainStatusModal txChainStatus model ]

        Nothing ->
            []
