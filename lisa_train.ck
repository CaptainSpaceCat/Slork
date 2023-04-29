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

//main loop
30 => int LISA_MAX_VOICES;
1::second => dur curr_pos;
me.dir() + "resources/scrape.wav" => string FILENAME;
load( FILENAME ) @=> LiSa2 @ lisa => dac;
1 => dac.gain;

RingBuf dist;
RingBuf distL;
0 => int noteShift_active => int onShift_active;
1 => int note_active;
[100000::samp, 480000::samp, 300000::samp, 600000::samp, 750000::samp] @=> dur note_map[];
-1 => int curr_note;
2 => float curr_rate;

// main loop
while( true )
{
    // random
    Math.random2f( 0.99, 1.01 ) * curr_rate => float newrate;
    Math.random2f( 50, 500 )::ms => dur newdur;

    // spork grain
    if (curr_note > -2) {
        //note_map[curr_note]
        spork ~ getgrain( curr_pos, newdur, 20::ms, 20::ms, newrate );
    }

    // note shift detection
    if (noteShift_active == 0 && Math.fabs(dist.read(0) - dist.read(2)) > 0.01) {
        1 => noteShift_active;
        spork ~ noteShift(dist.read(0) - dist.read(2));
    }
    
    if (onShift_active == 0 && Math.fabs(distL.read(0) - distL.read(2)) > 0.01) {
        1 => onShift_active;
        spork ~ onShift(dist.read(0) - dist.read(2));
    }
    
    if (note_active == 0) {
        0 => dac.gain;
    } else {
        0.2 => dac.gain;
    }
    
    // advance time
    10::ms => now;
}


// axis functions
fun void LX(float val) {
}
fun void LY(float val) {
    lerp(-1, 1, 2, 5, val) => curr_rate;
}
fun void LZ(float val) {
    //distL.add(val);
}
fun void RX(float val) {
}
fun void RY(float val) {
}
fun void RZ(float val) {
    dist.add(val);
    lisa.duration() => dur l;
    //<<<clamp(0, 1, lerp(0.05, 1, 0, 1, val)) * l>>>;
    clamp(0, 1, lerp(0.05, 1, 0, 1, val)) * l => curr_pos;
}

fun void noteShift(float val) {
    if (val > 0) {
        curr_note++;
    } else {
        curr_note--;
    }
    if (curr_note < -1 || curr_note >= note_map.cap()) {
        -1 => curr_note;
    }
    500::ms => now;
    0 => noteShift_active;
}

fun void onShift(float val) {
    if (val > 0) {
        note_active++;
    } else {
        note_active--;
    }
    if (note_active < 0) {
        0 => note_active;
    }
    if (note_active > 1) {
        1 => note_active;
    }
    500::ms => now;
    0 => onShift_active;
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


// sporkee: entry point for a grain!
fun void getgrain( dur pos, dur grainlen, dur rampup, dur rampdown, float rate )
{
    // get an available voice
    lisa.getVoice() => int newvoice;

    // make sure we got a valid voice   
    if( newvoice > -1 )
    {
        // set play rate
        lisa.rate(newvoice, rate);
        // set play position
        lisa.playPos(newvoice, pos);
        // lisa.playpos(newvoice, Math.random2f(0., 1000.)::ms);
        // set ramp up duration
        lisa.rampUp( newvoice, rampup );
        // wait for grain length (minus the ramp-up and -down)
        (grainlen - (rampup + rampdown)) => now;
        // set ramp down duration
        lisa.rampDown( newvoice, rampdown );
        // for ramp down duration
        rampdown => now;
    }
}

// load file into a LiSa
fun LiSa2 load( string filename )
{
    // sound buffer
    SndBuf buffy;
    // load it
    filename => buffy.read;
    
    // new LiSa
    LiSa2 lisa;
    // set duration
    buffy.samples()::samp*2 => lisa.duration;
    
    // transfer values from SndBuf to LiSa
    for( 0 => int i; i < buffy.samples()*2; i++ )
    {
        // args are sample value and sample index
        // (dur must be integral in samples)
        lisa.valueAt( buffy.valueAt(i), i::samp );        
    }
    
    // set LiSa parameters
    lisa.play( false );
    lisa.loop( false );
    lisa.maxVoices( LISA_MAX_VOICES );
    
    for( int v; v < lisa.maxVoices(); v++ )
    {
        // can pan across all available channels
        // note LiSa.pan( voice, [0...channels-1] )
        lisa.pan( v, v % lisa.channels() );
    }
    
    return lisa;
}

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
