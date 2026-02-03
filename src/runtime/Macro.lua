v3_one = math.Vector3(1.0, 1.0, 1.0)
v3_left = math.Vector3(0.0, 0.0, -1.0)
v3_right = math.Vector3(0.0, 0.0, 1.0)
v3_up = math.Vector3(-1.0, 0.0, 0.0)
v3_down = math.Vector3(1.0, 0.0, 0.0)

q_zero = math.Quaternion(0.0, 0.0, 0.0)

q_left = math.Quaternion(0.0, -180.0, 0.0)
q_right = q_zero
q_up = math.Quaternion(0.0, -90.0, 0.0)
q_down = math.Quaternion(0.0, 90.0, 0.0)

walk_speed = 7.0
vehicle_speed = 20.0
vehicle_accel = 20.0
fps = 30.0

forward_eca_event_ui = "ui_forward"

eca_event = {
    vehicle = {
        enter = "enter_vehicle",
        exit = "exit_vehicle",
        move = "move_vehicle",
        stop = "stop_vehicle",
    }

}
