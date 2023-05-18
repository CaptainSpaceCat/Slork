// pull up to breathe in hoarsely, drop down to scream
// actually invert the controls, drop down to inhale, pull up rapidly and flail arms to scream


GameTrak gt;

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

//main loop
while(true) {
    // random
    Math.random2f( 0.99, 1.01 ) * curr_rate => float newrate;
    Math.random2f( 1000, 2000 )::ms => dur newdur;
    //curr_pos + Math.random2(-200, 200)::ms => dur newpos;
    (Math.random2(voice_markers[curr_voice], voice_markers[curr_voice + 1]) *.95)::samp => dur newpos;
    
    if (screams_on == 1) {
        curr_gain => lisa.gain;
    } else {
        lisa.gain() * 0.6 => lisa.gain;
    }
    
    spork ~ getgrain( lisa, newpos, newdur, 50::ms, 50::ms, newrate, 0::ms);
    
    100::ms => now;
}

class GameTrak extends GameTrakInterface {
    fun void callback() {
        if (isButtonDown) {
            1 => screams_on;
        } else {
            0 => screams_on;
        }
        //LZ
        chain.update(axis[2]);
        lerp(-1, 1, 0.5, 1.5, axis[2]) => curr_chain_rate;
        
        //LZ
        1 + (lerp(0, 1, 0, 20, axis[5]) $ int) * 0.1 => curr_rate;
        clamp(0, 1, lerp(0, 0.05, 0, 1, axis[5])) => curr_gain;
    }
}

// ======================================================================================================= //

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

// simple util functions
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