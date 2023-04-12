1::second => now;

PulseOsc s3;
SawOsc s2;
TriOsc s1;
JCRev rs[5];
Gain node;
0 => node.gain;
s1 => node;

for (int i; i < 5; i++) {
    rs[i] => dac.chan(i);
    0.12 => rs[i].mix;
}


90 => float base_freq => float curr_freq;
0 => float offset_freq => float goal_freq;
2 => float distortion;
0 => float curr_gain;

100::ms => dur beat_length;
0.5 => float bip_percent;

0 => int curr_chan;
function void bip() {
    
    node =< rs[curr_chan];
    curr_chan++;
    5 %=> curr_chan;
    node => rs[curr_chan];
    //lerp(0, 30, 0, 0.02, distortion) => float offset_gain;
    Math.random2f(-0.02,0.02) + curr_gain => node.gain;
    //curr_gain => node.gain;
    
    Math.random2f(-distortion,distortion) + curr_freq => s1.freq;
    Math.random2f(-distortion,distortion) + curr_freq => s2.freq;
    Math.random2f(-distortion,distortion) + curr_freq => s3.freq;
    
    bip_percent * beat_length => now;
    
    0 => node.gain;
}


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

// gametrack
GameTrak gt;


// spork control
spork ~ gametrak();
// print
spork ~ print();

// main loop
while( true )
{
    if (offset_freq < goal_freq) {
        if (Math.random2(0, 3) == 0) {
            3 +=> offset_freq;
        }
    } else {
        if (Math.random2(0, 1) == 0) {
            3 -=> offset_freq;
        }
    }
    
    base_freq + offset_freq => curr_freq;
    bip();
    (1 - bip_percent) * beat_length => now;
    
    if (Math.random2(0,3) == 0) {
        //1 +=> offset_freq;
        /*
        NOTE:
        could have RY axis be current goal freq, and have it always randomly move up towards it
        but if we get too large, just instantly drop down, this way it wont go too high
        and also if i pull the clitch back it instantly drops
        */
    }
    
    if (Math.random2(0,100) == 0) {
        //0 => offset_freq;
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

// axis functions
fun void LX(float val) { // distortion
    lerp(-1, 1, 0, 30, val) => distortion;
}
fun void LY(float val) { // frequency
    lerp(-1, 1, 0, 600, val) => goal_freq;
}
fun void LZ(float val) { // gain
    lerp(0, 1, 0, 0.5, val) => curr_gain;
}
fun void RX(float val) { // bip percent
    lerp(-1, 1, -0.05, 1.05, val) => bip_percent;
    clamp(0, 1, bip_percent) => bip_percent;
}
fun void RY(float val) { // beat length
    lerp(-1, 1, 120, 1, val)::ms => beat_length;
}

int curr_gen;
fun void RZ(float val) {
    if (val < 0.05) {
        if (curr_gen != 0) {
            <<< "switching to s1" >>>;
            0 => curr_gen;
            s2 =< node;
            s3 =< node;
            s1 => node;
        }
    } else if (val < 0.1) {
        if (curr_gen != 1) {
            <<< "switching to s2" >>>;
            1 => curr_gen;
            s1 =< node;
            s3 =< node;
            s2 => node;
        }
    } else if (curr_gen != 2) {
        <<< "switching to s3" >>>;
        2 => curr_gen;
        s1 =< node;
        s2 =< node;
        s3 => node;
    }
            
    //timbre
    //we will change the oscillator
}

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
