2 => int N_chans;

me.dir() + "/resources/mixkit-bird-chirp.wav" => string filename;
SndBuf buf;
filename => buf.read;
2 => buf.gain;

NRev rs[N_chans];
ADSR adsrs[N_chans];
0 => int voice_on;

for (int i; i < N_chans; i++) {
    adsrs[i] => rs[i] => dac.chan(i);
    adsrs[i].set(30::ms, 10::ms, 0.3, 10::ms);
    0.1 => rs[i].mix;
    
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

while (true) {
    Math.random2(0, N_chans-1) => int c;
    blip(c);
}

fun void blip(int chan) {
    buf => adsrs[chan];
    0 => buf.pos;
    adsrs[chan].keyOn();
    Math.random2(0, 4)*50::ms => now;
    adsrs[chan].keyOff();
    10::ms => now;
    buf =< adsrs[chan];
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

fun void LX(float val) {
}
fun void LY(float val) {
}
fun void LZ(float val) {
}
fun void RX(float val) {
    56 => int base;
    stringPull(0, 30, 0.15, val) => float offset;
    //Std.mtof(base - 5) - offset => t.freq;
    //Std.mtof(base) + offset => s.freq;
    //Std.mtof(base+7) + offset => s2.freq;
}
fun void RY(float val) {
}
fun void RZ(float val) {
    //lerp(0, 1, 0, 2, val) => s.gain;
    //lerp(0, 1, 0, 1.8, val) => s2.gain;
    //lerp(0, 1, 0, 3, val) => t.gain;
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
                (voice_on + 1) % 2 => voice_on;
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
