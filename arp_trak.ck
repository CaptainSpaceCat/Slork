// =================================================
// cleantra.ck
// clean version of gametrak code
// organized to make it easy to gametrackify your code
// =================================================
// constants
2 => int N_chans;

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

SawOsc saw => ADSR adsr => LPF lpf => NRev rev => dac;
Osc sqr => adsr;
0.3 => saw.gain;
0 => sqr.gain;
adsr.set(30::ms, 20::ms, 0.3, 50::ms);
0.1 => rev.mix;
1200 => lpf.freq;
0.8 => lpf.Q;
spork ~ arpeggio();

0 => float walk_x => float walk_y;
0 => int curr_arp;


//main loop
while(true) {
    arp_clutch(angle(walk_x, walk_y));
    50::ms => now;
}

// axis functions
fun void LX(float val) {
}
fun void LY(float val) {
}
fun void LZ(float val) {
    //clamp(0, 1, lerp(0.05, 1, 0, 1, val)) => sqr.gain;
}
fun void RX(float val) {
    val => walk_x;
}
fun void RY(float val) {
    val => walk_y;
}
fun void RZ(float val) {
    clamp(0, 1, lerp(0.05, 1, 0, 1, val)) => saw.gain;
}

fun void arpeggio() {
    [
    [45, 47, 48, 52],
    [43, 45, 47, 50],
    [41, 43, 45, 48]
    ] @=> int notes[][];
    while(true) {
        for (int i; i < notes[0].cap(); i++) {
            Std.mtof(notes[curr_arp][i]) => saw.freq;
            Std.mtof(notes[curr_arp][0]-5) => sqr.freq;
            adsr.keyOn();
            150::ms => now;
            adsr.keyOff();
        }
    }
}

fun void arp_clutch(float curr_angle) {
    //<<<curr_angle>>>;
    if (curr_angle < 2.3) {
        0 => curr_arp;
    } else if (curr_angle < 4.0) {
        1 => curr_arp;
    } else {
        2 => curr_arp;
    }
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
                <<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}

// ============================================ Utility Functions ============================================
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
