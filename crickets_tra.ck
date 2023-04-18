// constants
2 => int N_chans;
10 => int N_crickets;

// z axis deadzone
0.05 => float DEADZONE;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
HidMsg msg;

// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();

// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// gametrack
GameTrak gt;
// =============================================== Main Loop ==============================================

// spork control
spork ~ gametrak();
// print
spork ~ print();

4750 => int base_freq;
LPF lpfs[N_chans];
for (int i; i < N_chans; i++) {
    base_freq => lpfs[i].freq;
    0.6 => lpfs[i].Q;
    lpfs[i] => dac.chan(i);
}

for (int i; i < N_crickets; i++) {
    spork ~ cricket(base_freq + lerp(0, N_crickets-1 $ float, -50, 50, i $ float) $ int, (17+Math.random2(-1, 1))::ms, Math.random2f(0.1, 0.4), i % N_chans);
}

fun void cricket(int freq, dur delay, float gain, int chan) {
    Math.random2(500, 5000)::ms => now;
    SinOsc t => ADSR e => lpfs[chan];
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    while(true) {
        now + Math.random2(1000, 1500)::ms => time stop;
        while(now < stop) {
            freq + Math.random2(-10, 10) => t.freq;
            gain * Math.random2f(0.95, 1.05) => t.gain;
            e.keyOn();
            delay => now;
            e.keyOff();
            delay => now;
        }
        Math.random2(2, 5)::second => now;
    }
}

//main loop
while(true) {
    100::ms => now;
}

// axis functions
fun void LX(float val) {
}
fun void LY(float val) {
}
fun void LZ(float val) {
}
fun void RX(float val) {
}
fun void RY(float val) {
}
fun void RZ(float val) {
}


// ============================================ Gametrak Code ============================================

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// hub
fun void trakHub(float axes[]) {
    LX(axes[0]);
    LY(axes[1]);
    LZ(axes[2]);
    RX(axes[3]);
    RY(axes[4]);
    RZ(axes[5]);
}

// print
fun void print()
{
    // time loop
    while( true )
    {
        // values
        //<<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2], gt.axis[3],gt.axis[4],gt.axis[5] >>>;
        //trakHub(gt.axis[0], gt.axis[1], gt.axis[2], gt.axis[3], gt.axis[4], gt.axis[5]);
        trakHub(gt.axis);
        // advance time
        100::ms => now;
    }
}

// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                //<<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                //<<< "button", msg.which, "up" >>>;
            }
        }
    }
}

// ============================================ Utility Functions ============================================
fun float lerp(float d_min, float d_max, float r_min, float r_max, float v) {
    (v - d_min) / (d_max - d_min) => float p;
    return p * (r_max - r_min) + r_min;
}

fun int lerp_int(int d_min, int d_max, int r_min, int r_max, int v) {
    (v - d_min) $ float / (d_max - d_min) => float p;
    return (p * (r_max - r_min) + r_min) $ int;
}

fun float clamp(float d_min, float d_max, float v) {
    if (v < d_min) {
        return d_min;
    }
    if (v > d_max) {
        return d_max;
    }
    return v;
}

fun float stringPull(float r_min, float r_max, float deadzone, float val) {
    Math.fabs(val) => val;
    clamp(0, 1, val - deadzone) * (1.0/(1-deadzone)) => val;
    return lerp(0, 1, r_min, r_max, val);
}
