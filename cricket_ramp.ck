// constants
2 => int N_chans;
10 => int N_crickets;

// vars
0 => int curr_mode;
1 => float curr_gain;
0 => int chorus_on;

// z axis deadzone
0.05 => float DEADZONE;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
Hid hi;
HidMsg msg;
HidMsg kmsg;

// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();
<<< "joystick '" + trak.name() + "' ready", "" >>>;

if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// gametrack
GameTrak gt;
// =============================================== Main Loop ==============================================

// spork control
spork ~ gametrak();
spork ~ keyboard();
// print
spork ~ print();

4750 => float base_freq;
110 => int base_note;
LPF lpfs[N_chans];
for (int i; i < N_chans; i++) {
    base_freq => lpfs[i].freq;
    0.6 => lpfs[i].Q;
    lpfs[i] => dac.chan(i);
}

/*
NOTES:
probably better to nix the alighning, just do it manually
by dropping all for a half sec, playing all, dropping, back to random

just make it a random chorus field
*/

Cricket2 cricks[N_crickets];
for (int i; i < N_crickets; i++) {
    cricks[i].set(base_freq, 350::ms, 500::ms, 15::ms, 0.2);
    cricks[i].set_phase(0.1 + 0.2*i);
    cricks[i].play(i%2);
}



12::second => dur rampdur;
fun void ramp() {
    for (int i; i < 100; i++) {
        base_freq + i*10 => float curr_freq;
        for (int n; n < N_crickets; n++) {
            cricks[n].set(curr_freq + lerp(0, 5, -70, 70, n), lerp(0, 100, 350, 1, i)::ms, lerp(0, 100, 500, 1, i)::ms, (13+(i%N_crickets))::ms, 0.2);
        }
        rampdur/100 => now;
    }
}

spork ~ ramp();

/*
CricketOsc crick_osc;
crick_osc.set_spacing(15::ms);
crick_osc.play(0);
for (int i; i < 100; i++) {
    crick_osc.set_freq(Std.mtof(base_note + Math.random2(-5, 5)));
    1::second => now;
}
*/

fun void start_random_crickets() {
    for (int i; i < N_crickets; i++) {
        spork ~ cricket(lerp(0, N_crickets-1 $ float, -100, 100, i $ float) $ int, (17+Math.random2(-1, 1))::ms, Math.random2f(0.05, 0.3), i % N_chans);
    }
}

fun void start_chorus_crickets() {
    for (int i; i < N_crickets; i++) {
        spork ~ chorus_cricket(lerp(0, N_crickets-1 $ float, -10, 10, i $ float) $ int, (17+Math.random2(-1, 1))::ms, Math.random2f(0.05, 0.3), i % N_chans);
    }
}

fun void start_harmonic_crickets() {
    [0, -2, -4, -2, 0, -2, 0, 3] @=> int harmonic1[];
    [3, 1, -1, -2, 3, 1, 3, 5] @=> int harmonic2[];
    for (int i; i < harmonic1.cap(); i++) {
        spork ~ robot_cricket(harmonic1[i], (17+Math.random2(-1, 1))::ms, Math.random2f(0.05, 0.3), i%N_chans, 1::second, 7::second, i::second);
    }
    for (int i; i < harmonic2.cap(); i++) {
        spork ~ robot_cricket(harmonic2[i], (17+Math.random2(-1, 1))::ms, Math.random2f(0.05, 0.3), (i+2)%N_chans, 1::second, 7::second, i::second);
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
    lerp(-1, 1, 4200, 5200, val) $ int => base_freq;
}
fun void RZ(float val) {
    lerp(0, 1, 0, 4, val) => curr_gain;
    
}
fun void BD() {
    (curr_mode + 1) % 3 => curr_mode;
    if (curr_mode == 0) {
        start_random_crickets();
    } else if (curr_mode == 1) {
        start_harmonic_crickets();
    } else {
        start_chorus_crickets();
    }
}
fun void BU() {
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
                BD();
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                //<<< "button", msg.which, "up" >>>;
                BU();
            }
        }
    }
}

fun void keyboard() {
    while( true )
    {
        // wait on event
        hi => now;
        
        // get one or more messages
        while( hi.recv( kmsg ) )
        {
            if (kmsg.which == 44) {
                // check for action type
                if( kmsg.isButtonDown() )
                {
                    //<<< "down:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
                    1 => chorus_on;
                }
                
                else
                {
                    //<<< "up:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
                    0 => chorus_on;
                }
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

class CricketOsc
{
    0 => int isPlaying;
    SinOsc t => ADSR e => ADSR o;
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    o.set(30::ms, 10::ms, 0.3, 40::ms);
    
    0 => int chan;
    15::ms => dur spacing;
    
    public void set_spacing(dur _spacing) {
        _spacing => spacing;
    }
    
    public void set_freq(float _freq) {
        _freq => t.freq;
    }
    
    public void play(int _chan) {
        if (isPlaying == 0) {
            _chan => chan;
            o => lpfs[chan];
            1 => isPlaying;
            spork ~ sounds();
        }
    }
    
    public void stop() {
        0 => isPlaying;
    }
    
    private void sounds() {
        o.keyOn();
        while (isPlaying == 1) {
            e.keyOn();
            spacing => now;
            e.keyOff();
            spacing => now;
        }
        o.keyOff();
        e.keyOn();
        spacing => now;
        e.keyOff();
        o =< lpfs[chan];
    }
}

class Cricket2
{
    0 => int isPlaying;
    SinOsc t => ADSR e => ADSR o;
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    o.set(30::ms, 10::ms, 0.3, 40::ms);
    
    0 => int chan;
    350::ms => dur len;
    500::ms => dur delay;
    15::ms => dur spacing;
    0::ms => dur offset;
    0 => float phase_factor;
    0 => int num_loops;
    
    public void set_phase(float _factor) {
        _factor => phase_factor;
    }
    
    public void set(float _freq, dur _len, dur _delay, dur _spacing, float _gain) {
        _gain => t.gain;
        _freq => t.freq;
        _len => len;
        _delay => delay;
        _spacing => spacing;
    }
    
    public void set_freq(float _freq) {
        _freq => t.freq;
    }
    
    public void play(int _chan) {
        if (isPlaying == 0) {
            _chan => chan;
            o => lpfs[chan];
            1 => isPlaying;
            spork ~ sounds();
        }
    }
    
    public void stop() {
        0 => isPlaying;
    }
    
    private void sounds() {
        while (isPlaying == 1) {
            now + len => time stop;
            o.keyOn();
            while(now < stop) {
                e.keyOn();
                spacing => now;
                e.keyOff();
                spacing => now;
            }
            o.keyOff();
            e.keyOn();
            spacing => now;
            e.keyOff();
            
            (phase_factor*num_loops/(2*Math.pi)) % 1 => float p;
            lerp(-1, 1, .5, 1.5, Math.sin((2*Math.pi)*p)) => float offset;
            delay * offset => now;
            num_loops++;
        }
        o =< lpfs[chan];
    }
}

fun void cricket(int delta_freq, dur delay, float gain, int chan) {
    Math.random2(500, 5000)::ms => now;
    SinOsc t => ADSR e => lpfs[chan];
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    while(curr_mode == 0) {
        now + Math.random2(1000, 1500)::ms => time stop;
        while(now < stop) {
            base_freq + delta_freq + Math.random2(-10, 10) => t.freq;
            gain * Math.random2f(0.95, 1.05) * curr_gain => t.gain;
            e.keyOn();
            delay => now;
            e.keyOff();
            delay => now;
        }
        Math.random2(2, 5)::second => now;
    }
}

fun void chorus_cricket(int delta_freq, dur delay, float gain, int chan) {
    Math.random2(500, 5000)::ms => now;
    SinOsc t => ADSR e => lpfs[chan];
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    while(curr_mode == 2) {
        now + Math.random2(1000, 1500)::ms => time stop;
        while(now < stop) {
            base_freq + delta_freq + Math.random2(-10, 10) => t.freq;
            gain * Math.random2f(0.95, 1.05) => t.gain;
            if (chorus_on == 1) {
                e.keyOn();
                delay => now;
                e.keyOff();
                delay => now;
            } else {
                10::ms => now;
            }
        }
        Math.random2(2, 5)::second => now;
    }
}

fun void robot_cricket(int delta_note, dur delay, float gain, int chan, dur chirp_len, dur pause_len, dur predelay) {
    predelay => now;
    SinOsc t => ADSR e => lpfs[chan];
    e.set(20::ms, 5::ms, 0.3, 10::ms);
    while(curr_mode == 1) {
        now + chirp_len => time stop;
        while(now < stop) {
            Std.mtof(base_note + delta_note) => t.freq;
            gain * Math.random2f(0.95, 1.05) => t.gain;
            e.keyOn();
            delay => now;
            e.keyOff();
            delay => now;
        }
        pause_len => now;
    }
}
