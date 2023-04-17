me.dir() + "/resources/mixkit-bird-chirp.wav" => string filename;
SndBuf buf => ADSR adsr => NRev r => dac;
filename => buf.read;
0.1 => r.mix;
adsr.set(30::ms, 10::ms, 0.3, 10::ms);

while (true) {
    blip();
}

fun void blip() {
    Math.random2f(0.95, 1.05) => buf.rate;
    0 => buf.pos;
    adsr.keyOn();
    //Math.random2(40, 180)::ms => now;
    Math.random2(1, 4)*50::ms => now;
    adsr.keyOff();
    10::ms => now;
}
