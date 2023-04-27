// constants
2 => int N_chans;

// z axis deadzone
0.05 => float DEADZONE;
0 => int footstep_active;

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

SndBuf buf => PitShift pit => LPF lpf => ADSR adsr => NRev rv => Gain g => dac;
adsr.set(50::ms, 1000::ms, 0.1, 50::ms);
0.2 => buf.gain;
3200 => lpf.freq;
0.08 => rv.mix;
3 => float base_gain;
1 => pit.mix;
me.dir() + "/resources/thunder.wav" => buf.read;

0 => float walk_x => float walk_y;
RingBuf ring;
0 => int footstep_count;
0 => int footstep_phase;

//main loop
while(true) {
    ring.add(angle(walk_x, walk_y));
    //<<< angle(walk_x, walk_y) >>>;
    //<<< ring.read(0), ring.read(-1), Math.fabs(ring.read(0) - ring.read(-1)) >>>;
    if (Math.fabs(ring.read(0) - ring.read(5)) > 0.1) {
        footstep();
    }
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
    val => walk_x;
}
fun void RY(float val) {
    val => walk_y;
}
fun void RZ(float val) {
}

fun void footstep() {
    if (footstep_active == 0) {
        1 => footstep_active;
        <<< "Footstep!" >>>;
        spork ~ footstep_sound();
    }
}

fun void footstep_sound() {
    [0, 30000] @=> int choices[];
    Math.random2f(0,2) => int p;
    choices[p $ int] => int c => buf.pos;
    //<<<p, c>>>;
    Math.random2f(0.9, 1.1) => pit.shift;
    base_gain * Math.random2f(0.7, 1.3) => g.gain;
    adsr.keyOn();
    1000::ms => now;
    0 => footstep_active;
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
class RingBuf
{
    float buffer[10];
    0 => int index;
    0 => int count;
    
    public void add(float v) {
        v => buffer[index];
        (index+1) % 10 => index;
        if (count < 10) {
            count++;
        }
    }
    
    public float read(int i) {
        if (count < 10) {
            return 0.0;
        }
        return buffer[(index + 9 - i) % 10];
    }
}

fun float lerp(float d_min, float d_max, float r_min, float r_max, float v) {
    (v - d_min) / (d_max - d_min) => float p;
    return p * (r_max - r_min) + r_min;
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

fun float angle(float a, float b) {
    //difference between <a, b> and <0, 1>
    Math.acos(b / (Math.fabs(a)+Math.fabs(b))) => float angle;
    if (a < 0) {
        2*Math.pi - angle => angle;
    }
    //return Math.atan(b/a);
    return angle;
}
