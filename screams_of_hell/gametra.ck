// data structure for gametrak
public class GameTrakInterface {
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
    
    int isButtonDown;
    
    spork ~ _gametrak();
    
    fun void callback() {}
    
    fun void _gametrak() {
        // z axis deadzone
        .008 => float DEADZONE;
        
        // which joystick
        0 => int device;
        
        // HID objects
        Hid trak;
        HidMsg msg;
        
        // open joystick 0, exit on fail
        if (!trak.openJoystick(device)) me.exit();
        <<< "joystick '" + trak.name() + "' ready", "" >>>;
        
        while (true) {
            // wait on HidIn as event
            trak => now;
            
            // messages received
            while (trak.recv(msg)) {
                // joystick button motion
                if (msg.isButtonDown()) {
                    // <<< "button", msg.which, "down" >>>;
                    1 => isButtonDown;
                } else if (msg.isButtonUp()) {
                    // <<< "button", msg.which, "up" >>>;
                    0 => isButtonDown;
                } else if (!msg.isAxisMotion()) continue;
                
                // joystick axis
                // filter which
                if (msg.which < 0 || msg.which >= 6) continue;
                
                // check if fresh
                if (now > currTime) {
                    // time stamp
                    currTime => lastTime;
                    // set
                    now => currTime;
                }
                // save last
                axis[msg.which] => lastAxis[msg.which];
                // the z axes map to [0,1], others map to [-1,1]
                if (msg.which != 2 && msg.which != 5) {
                    msg.axisPosition => axis[msg.which];
                    continue;
                }
                1 - ((msg.axisPosition + 1) / 2) => axis[msg.which];
                // take care of deadzones
                if (msg.which == 2 || msg.which == 5)
                    axis[msg.which] - DEADZONE => axis[msg.which];
                // make sure non-negative
                if (axis[msg.which] < 0) 0 => axis[msg.which];
                
                callback();
            }
        }
    }
}