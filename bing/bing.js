const canvas = document.getElementById("canvas");
const svg = document.getElementById("svg");
//svg.setAttribute("width", "1000");
//svg.setAttribute("height", "1000");
const context = canvas.getContext("2d");

Y = 0;
const NOTES = [0, 1, .3, .6, .2, .15, .2, .15, .5];
const DURS  = [5, 3,  2,  7,  1, 1, 1, 1, 3];
const SLURS = [0, 0, 0, 0, 1, 1, 1, 0, 0];
const WIN_NOTES = 12;
const BPS = 1;
let startTime = 0;
function draw(time) {
    if (startTime == 0) {
        startTime = time;
    }
    pos = (time - startTime) / 1000 //pos is how far along the song we have gotten
    let curr_beat = pos/BPS; // seconds elapsed / beats per second = beats elapsed
    const width = canvas.width = window.innerWidth;
    const height = canvas.height = window.innerHeight;
    context.fillStyle = "black";
    context.fillRect(0, 0, width, height);
    let so_far = 0;  //how far are we along the current render
    let drawn = 0;
    for (let i = 0; i < NOTES.length; i++) {
        so_far += DURS[i];
        if (so_far >= pos) {
            let dur = DURS[i] * .9;
            if (so_far - DURS[i] < pos) {
                dur = so_far - pos;
            }
            const x = (drawn / WIN) * (width - 90) + 90;
            const y = NOTES[i] * (height - 20) + 10;
            const rect_width = (dur / WIN) * (width - 90)
            //context.fillStyle = "blue";
            //context.fillRect(x, y - 10, rect_width, 20);

            context.beginPath();
            context.moveTo(x, y-10);
            context.lineTo(x + rect_width, y-10);
            context.strokeStyle = "blue";
            context.lineWidth = 10;
            context.stroke();
            drawn += dur;
        }
    }

    context.beginPath();
    context.moveTo(90, 0);
    context.lineTo(90, height);
    context.strokeStyle = "white";
    context.stroke();

    const y = (1 - Y) * height;
    context.beginPath();
    context.moveTo(90, y);
    context.arc(90, y, 10, 0, 2 * Math.PI);
    context.fillStyle = "white";
    context.fill();


    requestAnimationFrame(draw);
}

function renderNote() {
    let i = 0;
    while (i < NOTES.length) {
        
        context.beginPath();
        //context.arc(, noteToPos(NOTES[i]));
        //context.moveTo(, noteToPos(NOTES[i]));
        //context.lineTo();
        while (SLURS[i] == 1) {
            //add the next note in the slur until we get through all of it
        }

    }
}

function noteToPos(note) {
    return note * (height - 20) + 10;
}

document.body.onclick = function() {
    canvas.requestFullscreen();
}

// start animation
requestAnimationFrame(draw);

// start up websocket
const ws = new WebSocket("ws://localhost:12345");
ws.addEventListener("open", () => {
});
ws.addEventListener("message", (event) => {
    const {Which: which, Val: val} = JSON.parse(event.data);
    Y = val;
});
