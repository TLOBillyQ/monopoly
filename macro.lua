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

FORWARD_EVENT_UI = "ui_forward"
FORWARD_EVENT_ENTER_VEHICLE = "enter_vehicle_forward"
FORWARD_EVENT_EXIT_VEHICLE = "exit_vehicle_forward"
FORWARD_EVENT_MOVE_VEHICLE = "move_vehicle_forward"
FORWARD_EVENT_STOP_VEHICLE = "stop_vehicle_forward"