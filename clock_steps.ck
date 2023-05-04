// constants
2 => int N_chans;
3 => int N_crickets;

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
0 => float walk_x => float walk_y;

// spork control
spork ~ gametrak();
// print
spork ~ print();

LPF lpfs[N_chans];
for (int i; i < N_chans; i++) {
    1200 => lpfs[i].freq;
    0.6 => lpfs[i].Q;
    lpfs[i] => dac.chan(i);
}

ClockTicker ticker;
FootstepTracker tracker;
CricketOsc cricks[6];
for (int i; i < N_crickets; i++) {
    cricks[i].set_gain(3);
    cricks[i].set_spacing((15+Math.random2(-2, 2))::ms);
}

MultiOsc mosc;
Shakers shake => dac;
0 => shake.preset;

SndBuf clock_buf => Gain g => PitShift pit => LPF lpf => ADSR adsr => NRev rv => dac;
adsr.set(50::ms, 1000::ms, 0.1, 50::ms);
0.2 => clock_buf.gain;
3200 => lpf.freq;
0.08 => rv.mix;
5 => float base_gain;
1 => pit.mix;
me.dir() + "/resources/thunder.wav" => clock_buf.read;

tracker.start();
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
    val => walk_x;
}
fun void RY(float val) {
    val => walk_y;
}
fun void RZ(float val) {
}


fun void clockMeasure(dur d, int r) {
    [0, 2, 4, 6] @=> int offsets[];
    
    //bell
    //mosc.play();
    [0, 30000] @=> int choices[];
    Math.random2f(0,2) => float p;
    choices[p $ int] => int c => clock_buf.pos;
    //Math.random2f(0.9, 1.1) => pit.shift;
    base_gain * Math.random2f(0.7, 1.3) => g.gain;
    adsr.keyOn();
    
    for (int c; c < 4; c++) {
        220 * (c%2+1) => shake.freq;
        shake.noteOn(3);
        d/4 => now;
        mosc.stop();
    }
    
    if (r > 0) {
        clockMeasure(d, r-1);
    }
}

class MultiOsc
{
    SawOsc saw => ADSR adsr1 => LPF lpf1 => NRev r1 => dac;
    SqrOsc sqr => ADSR adsr2 => LPF lpf2 => NRev r2 => dac;
    .8 => saw.gain => sqr.gain;
    Std.mtof(69) => saw.freq;
    Std.mtof(64) => sqr.freq;
    800 => lpf1.freq;
    700 => lpf2.freq;
    0.5 => lpf1.Q => lpf2.Q;
    0.2 => r1.mix => r2.mix;
    adsr1.set(20::ms, 50::ms, 0.5, 1::second);
    adsr2.set(20::ms, 50::ms, 0.3, 1::second);
    
    public void play() {
        adsr1.keyOn();
        adsr2.keyOn();
    }
    
    public void stop() {
        adsr1.keyOff();
        adsr2.keyOff();
    }
}

class ClockTicker
{
    SinOsc s;
    now => time lastTick;
    dur length;
    3 => int beats;
    
    public void setNextTick() {
        now - lastTick - 20::ms => length;
        if (length > 4::second) {
            4::second => length;
        }
        //spork ~ tickSounds();
        spork ~ clockMeasure(length, 0);
        now => lastTick;
    }
    
    
    // the rest of the class is used to debug the clock
    private void tickSounds() {
        for (int i; i < beats; i++) {
            spork ~ tick(i);
            length/beats => now;
        }
    }
    
    private void tick(int idx) {
        Std.mtof(50 + idx*4) => s.freq;
        s => dac;
        100::ms => now;
        s =< dac;
    }
}

class FootstepTracker
{
    0 => float last_angle => float curr_angle;
    0 => float stable_angle;
    0 => int step_active => int stabilizing;
    1000::ms => dur duration;
    
    public void set(dur d) {
        d => duration;
    }
    
    public void start() {
        while (!(angle(walk_x, walk_y) >= 0)) {
            10::ms => now;
        }
        angle(walk_x, walk_y) => curr_angle => last_angle => stable_angle;
        spork ~ trackerLoop();
    }
    
    private void trackerLoop() {
        0 => int c_zeros;
        while (true) {
            angle(walk_x, walk_y) => curr_angle;
            //<<<curr_angle, last_angle, stable_angle, stabilizing>>>;
            if (Math.fabs(curr_angle - last_angle) < 0.01) {
                c_zeros++;
            } else {
                0 => c_zeros;
            }
            
            if (stabilizing == 0 && Math.fabs(curr_angle - stable_angle) > 0.12) {
                1 => stabilizing;
                stepOn();
            }
            
            if (stabilizing == 1 && c_zeros >= 5) {
                curr_angle => stable_angle;
                0 => stabilizing;
            }
            curr_angle => last_angle;
            100::ms => now;
        }
    }
    
    private void stepOn() {
        if (step_active == 0) {
            1 => step_active;
            footstep();
            spork ~ delay();
        }
    }
    
    private void delay() {
        duration => now;
        0 => step_active;
    }
    
    private void footstep() {
        // call external function to make footstep sound
        ticker.setNextTick();
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

fun float angle(float a, float b) {
    //difference between <a, b> and <0, 1>
    Math.acos(b / (Math.fabs(a)+Math.fabs(b))) => float angle;
    if (a < 0) {
        2*Math.pi - angle => angle;
    }
    //return Math.atan(b/a);
    return angle;
}

class CricketOsc
{
    0 => int isPlaying;
    SinOsc t => ADSR e => ADSR o;
    e.set(20::ms, 5::ms, 1, 10::ms);
    o.set(30::ms, 10::ms, 1, 40::ms);
    
    0 => int chan;
    15::ms => dur spacing;
    
    public void set_spacing(dur _spacing) {
        _spacing => spacing;
        
    }
    
    public void set_freq(float _freq) {
        _freq => t.freq;
    }
    
    public void set_gain(float _gain) {
        _gain => t.gain;
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
        Math.random2f(0,1)*spacing => now;
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
