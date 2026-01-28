V3_ONE = math.Vector3(1, 1, 1)
V3_LEFT = math.Vector3(0, 0, -1)
V3_RIGHT = math.Vector3(0, 0, 1)
V3_UP = math.Vector3(-1, 0, 0)
V3_DOWN = math.Vector3(1, 0, 0)

Q_ZERO = math.Quaternion(0, 0, 0)

Q_LEFT = math.Quaternion(0, -180, 0)
Q_RIGHT = Q_ZERO
Q_UP = math.Quaternion(0, -90, 0)
Q_DOWN = math.Quaternion(0, 90, 0)

WALK_SPEED = 7.0
VEHICLE_SPEED = 20.0
VEHICLE_ACCEL = 20.0

FORWARD_ECA_EVENT_UI = "ui_forward"

ECA_EVENT = {
    UI = {
        open_base_screen = "open_base_screen",
        close_base_screen = "close_base_screen",
        open_modal_choice = "open_modal_choice",
        close_modal_choice = "close_modal_choice",
        open_modal_popup = "open_modal_popup",
        close_modal_popup = "close_modal_popup",
        open_market_panel = "open_market_panel",
        close_market_panel = "close_market_panel",
        open_loading_screen = "open_loading_screen",
        close_loading_screen = "close_loading_screen",
    },
    VEHICLE = {
        enter = "enter_vehicle",
        exit = "exit_vehicle",
        move = "move_vehicle",
        stop = "stop_vehicle",
    }

}
