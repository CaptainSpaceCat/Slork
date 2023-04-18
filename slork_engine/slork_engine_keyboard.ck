SqrOsc s => JCRev r => dac;
.15 => s.gain;
0.2 => r.mix;

90 => int base_freq => int curr_freq;
0 => int offset_freq;
2 => int distortion;

100::ms => dur beat_length;
0.5 => float bip_percent;



Hid hi;
HidMsg msg;

// which keyboard
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;


fun void eventHandler() {
    // infinite event loop
    while( true )
    {
        // wait on event
        hi => now;

        // get one or more messages
        while( hi.recv( msg ) )
        {
            // check for action type
            if( msg.isButtonDown() )
            {
                if (msg.which == 200) {
                    2 +=> offset_freq;
                    <<< "offset_freq: ", offset_freq >>>;
                } else if (msg.which == 208) {
                    2 -=> offset_freq;
                    <<< "offset_freq: ", offset_freq >>>;
                }
                if (offset_freq < 0) {
                    0 => offset_freq;
                }
                
                if (msg.which == 205) {
                    1 +=> distortion;
                    <<< "distortion: ", distortion >>>;
                } else if (msg.which == 203) {
                    1 -=> distortion;
                    <<< "distortion: ", distortion >>>;
                }
                if (distortion < 0) {
                    0 => distortion;
                }
                
                
                
                if (msg.which == 72) {
                    2::ms +=> beat_length;
                    <<< "beat_length: ", beat_length >>>;
                } else if (msg.which == 80) {
                    2::ms -=> beat_length;
                    <<< "beat_length: ", beat_length >>>;
                }
                if (beat_length < 4::ms) {
                    4::ms => beat_length;
                }
                
                if (msg.which == 77) {
                    0.05 +=> bip_percent;
                    <<< "bip_percent: ", bip_percent >>>;
                } else if (msg.which == 75) {
                    0.05 -=> bip_percent;
                    <<< "bip_percent: ", bip_percent >>>;
                }
                if (bip_percent < 0) {
                    0 => bip_percent;
                }
                if (bip_percent > 1) {
                    1 => bip_percent;
                }
                   
            }
            
            else
            {
                //<<< "up:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
            }
        }
    }
}

spork ~ eventHandler();


function void bip() {
    .15 => s.gain;
    Math.random2(-distortion,distortion) + curr_freq => s.freq;

    bip_percent * beat_length => now;
    
    0 => s.gain;
}


while(true) {
    base_freq + offset_freq => curr_freq;
    bip();
    (1 - bip_percent) * beat_length => now;
    
    if (Math.random2(0,3) == 0) {
        //1 +=> offset_freq;
    }
    
    if (Math.random2(0,100) == 0) {
        //0 => offset_freq;
    }
}


/* axes for gametrak
R X - delay
R Y - length
R Z - ?
L Y - current frequency
L X - distortion
L Z - gain
*/

