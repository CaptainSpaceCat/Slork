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
load( me.dir() + "resources/screams.wav" ) @=> LiSa2 @ lisa => dac;
load( me.dir() + "resources/clink.wav" ) @=> LiSa2 @ lisa_chain => dac;
1 => float curr_gain;
0 => int screams_on;
2 => float curr_rate => float curr_chain_rate;
0 => int curr_voice;
[0, 170928, 306404] @=> int voice_markers[];
ChainYanker chain;

while(true) {
    // random
    Math.random2f( 0.99, 1.01 ) * curr_rate => float newrate;
    Math.random2f( 500, 1000 )::ms => dur newdur;
    //curr_pos + Math.random2(-200, 200)::ms => dur newpos;
    (Math.random2(voice_markers[curr_voice], voice_markers[curr_voice + 1]) *.95)::samp => dur newpos;
    
    if (screams_on == 1) {
        curr_gain => lisa.gain;
    } else {
        lisa.gain() * 0.6 => lisa.gain;
    }
    
    spork ~ getgrain( lisa, newpos, newdur, 50::ms, 50::ms, newrate, 0::ms);
    
    60::ms => now;
}

// axis functions
fun void LX(float val) {
}
fun void LY(float val) {
    lerp(-1, 1, 0.5, 1.5, val) => curr_chain_rate;
}
fun void LZ(float val) {
    //chain
    chain.update(val);
}
fun void RX(float val) {
}
fun void RY(float val) {
    if (val < 0) {
        0 => curr_voice;
    } else {
        1 => curr_voice;
    }
}
fun void RZ(float val) {
    // scream note
    1 + (lerp(0, 1, 0, 20, val) $ int) * 0.1 => curr_rate;
    clamp(0, 1, lerp(0, 0.05, 0, 1, val)) => curr_gain;
}

class ChainYanker
{
    100 => int N_links;
    0 => float lastVal;
    
    public void set(int l) {
        l => N_links;
    }
    
    public void update(float val) {
        getLinkDelta(val, lastVal) => int delta;
        lerp(0, 0.2, 0.5, 2, Math.fabs(val - lastVal)) => lisa_chain.gain;
        chainSound(Math.abs(delta));
        
        val => lastVal;
    }
    
    private int getLinkDelta(float a, float b) {
        return ((a * N_links) $ int) - ((b * N_links) $ int);
    }
    
    private void chainSound(int count) {
        for (int i; i < count; i++) {
            spork ~ getgrain( lisa_chain, 0::ms, 100::ms, 10::ms, 30::ms, Math.random2f(0.9, 1.1) * curr_chain_rate, i * Math.random2(25, 35)::ms );
        }
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
                //<<< "button", msg.which, "down" >>>;
                1 => screams_on;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                //<<< "button", msg.which, "up" >>>;
                0 => screams_on;
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

// sporkee: entry point for a grain!
fun void getgrain(LiSa2 lisa_chosen, dur pos, dur grainlen, dur rampup, dur rampdown, float rate, dur predelay)
{
    predelay => now;
    // get an available voice
    lisa_chosen.getVoice() => int newvoice;
    
    // make sure we got a valid voice   
    if( newvoice > -1 )
    {
        // set play rate
        lisa_chosen.rate(newvoice, rate);
        // set play position
        lisa_chosen.playPos(newvoice, pos);
        // lisa.playpos(newvoice, Math.random2f(0., 1000.)::ms);
        // set ramp up duration
        lisa_chosen.rampUp( newvoice, rampup );
        // wait for grain length (minus the ramp-up and -down)
        (grainlen - (rampup + rampdown)) => now;
        // set ramp down duration
        lisa_chosen.rampDown( newvoice, rampdown );
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
