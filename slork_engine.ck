1::second => now;

PulseOsc s3;
SawOsc s2;
TriOsc s1;
SawOsc s_acc => NRev r_acc;
0.12 => r_acc.mix;
JCRev rs[5];
Gain node;
0 => node.gain;
s1 => node;

for (int i; i < 5; i++) {
    rs[i] => dac.chan(i);
    0.12 => rs[i].mix;
}


90 => float curr_freq;
0 => float goal_freq;
2 => float distortion;
0 => float curr_gain;
0 => int curr_mode;
0 => int curr_gen;
int curr_bucket;

100::ms => dur beat_length;
0.5 => float bip_percent;

0 => int curr_chan;
function void bip() {
    
    node =< rs[curr_chan];
    curr_chan++;
    5 %=> curr_chan;
    node => rs[curr_chan];
    Math.random2f(-0.02,0.02) + curr_gain => node.gain;
    
    Math.random2f(-distortion,distortion) + curr_freq => s1.freq;
    Math.random2f(-distortion,distortion) + curr_freq => s2.freq;
    Math.random2f(-distortion,distortion) + curr_freq => s3.freq;
    
    bip_percent * beat_length => now;
    
    0 => node.gain;
}

fun void accompany() {
    r_acc => dac.chan(5);
    0 => int o;
    scale_frequency(155.56, o) => s_acc.freq;
    for (int i; i < 100; i++) {
        i/100.0 => float p;
        p * curr_gain => s_acc.gain;
        20::ms => now;
    }
    while(curr_mode == 1) {
        o++;
        2 %=> o;
        //scale_frequency(174.61, curr_bucket-3) => s_acc.freq;
        scale_frequency(155.56, o) => s_acc.freq;
        for (int i; i < 50; i++) {
            0 => s_acc.gain;
            20::ms => now;
            curr_gain => s_acc.gain;
            20::ms => now;
        }
    }
    for (int i; i < 100; i++) {
        (100-i)/100.0 => float p;
        p * curr_gain => s_acc.gain;
        40::ms => now;
    }
    r_acc =< dac.chan(5);
}

fun float scale_frequency(float base, int offset) {
    [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24] @=> int deltas[];
    //base 174.61
    return base*Math.pow(2, deltas[offset]/12.0);
}


// z axis deadzone
0.02 => float DEADZONE;

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
// frequency following
spork ~ freq_follow();

fun void freq_follow() {
    while (true) {
        curr_freq - goal_freq => float delta;
        if (delta < 0) {
            -delta => delta;
        }
        if (delta < 3) {
            goal_freq => curr_freq;
        } else {
            if (curr_freq < goal_freq) {
                if (Math.random2(0, 3) == 0) {
                    2 +=> curr_freq;
                }
            } else {
                if (Math.random2(0, 1) == 0) {
                    2 -=> curr_freq;
                }
            }
        }
        5::ms => now;
    }
}

// main loop
while( true )
{
    bip();
    (1 - bip_percent) * beat_length => now;
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

fun int buckets(float d_min, float d_max, int n_buckets, float v) {
    v/(d_max-d_min) => float p;
    return Math.floor(p*n_buckets) $ int;
}

// axis functions
fun void LX(float val) { // distortion
    if (curr_mode == 0) {
        lerp(-1, 1, 0, 30, val) => distortion;
    } else {
        0 => distortion;
    }
}
fun void LY(float val) { // timbre clutch
    if (val < -0.5) {
        if (curr_gen != 0) {
            <<< "switching to s1" >>>;
            0 => curr_gen;
            s2 =< node;
            s3 =< node;
            s1 => node;
        }
    } else if (val < 0.3) {
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
}
fun void LZ(float val) { // pitch
    if (curr_mode == 0) {
        lerp(0, 0.4, 0, 600, val) => goal_freq;
    } else {
        buckets(0, 0.5, 10, val) => curr_bucket;
        scale_frequency(174.61, curr_bucket) => goal_freq;
    }
    <<<goal_freq, curr_freq>>>;
}
fun void RX(float val) { // bip percent
    lerp(-1, 1, -0.05, 1.05, val) => bip_percent;
    clamp(0, 1, bip_percent) => bip_percent;
}
fun void RY(float val) { // beat length
    lerp(-1, 1, 120, 1, val)::ms => beat_length;
}
fun void RZ(float val) {
    lerp(0, 1, 0, 2, val) => curr_gain;
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
                curr_mode++;
                2 %=> curr_mode;
                if (curr_mode == 1) {
                    //spork ~ accompany();
                }
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                //<<< "button", msg.which, "up" >>>;
            }
        }
    }
}
