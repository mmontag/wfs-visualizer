static final int h = 300;
static final int w = 600;

/* 
 
 TODO:
 -close source optimizations: turn array into simple phantom source when virtual source is very close to array
 -multiple array configurations:
 circular array - adjustments for array radius (or speaker spacing), and number of speakers
 windowing off
 box array - adjustmens for speaker spacing and box width/height (integer number of speakers)
 strange windowing based on listener position
 -fdtd solution to wave equation
 -properly adjust amplitude based on source distance
 
 */
PFont fontA;

float t; //stores time ticks
float timestep = 3; //speed-up factor. sound normally propagates at 1 pixel per frame
float c = 1; //speed of sound in pixels per frame
int xpos = 150; //x-position of array
ArrayList loudspeakers;
Loudspeaker em, em2;
PImage lsicon; // = createImage(10,16,ARGB); //a loudspeaker icon
PGraphics buffer; //an offscreen buffer for drawing downsampled graphics
int upsample = 6;
int wd;
int hd;

/************************
 * Array Setup
 ************************/
float lx = xpos + (w-xpos)/2; //listener position - for determining speaker enablement
float ly = h/2;
float vsrcx = 0;//virtual loudspeaker position
float vsrcy = h/4;
float num = 20; //number of loudspeakers
float dst = 20; //distance between loudspeakers
float wavelength = 40; //wavelength of signal
int randomize = 0;
int signaltype = 0;
String signallabel;
int roundtime = 0;
int primarywave = 0;
int numsignaltypes = 3; //sine, noise, saw
float wpower = 1; //cos^wpower adjusts steepness of windowing
float taperwidth = .2;

void setup() {
    size(w,h);
    lsicon = loadImage("loudspeaker_black.gif");
    initBuffer();
    initArray();
    t = 0;
    fontA = loadFont("Tahoma-11.vlw");
    loadPixels();
}

void initBuffer() { 
    wd = w/upsample;
    hd = h/upsample;
    buffer = createGraphics(wd,hd,JAVA2D);
    buffer.loadPixels();
}

void initArray() {
    loudspeakers = new ArrayList();
    float amp;
    float dly;
    float len = (num-1)*dst; //total size of array
    float ypos1 = (h-len)/2; //starting position of loudspeakers -- center vertically
    float freq = 1/wavelength; //frequency of signal

    for(int i = 0; i < num; i++) {
        //position
        float ypos = ypos1 + i*dst;
        if (randomize==1) {
            float rnd = 0.50; //randomization factor 10-50%
            ypos = ypos + random(rnd*-dst/2, rnd*dst/2);
            amp = 1;//cos(2*PI*((ypos-ypos1)/wavelength)); //testing amplitude correction in randomized array
        } 
        else {
            amp = 1;
        }
        //window 
        float pos = map(ypos, ypos1-dst, ypos1+len+dst, 0, 1);
        float window = taper(pos);
        //float window = 2*pow(sin(PI*(ypos-ypos1)/len),2); //sidelobe-diffraction suppression windowing coefficient
        amp = window * amp;
        println(amp);

        //interactive loudspeaker position
        vsrcx = mouseX;
        vsrcy = mouseY;

        //delay
        int sign = 1; 
        if(vsrcx < xpos) sign = -1; 
        dly = sign * sqrt(pow(xpos-vsrcx,2) + pow(ypos-vsrcy,2)) / c; //travel time = distance over speed of propagation

        loudspeakers.add(new Loudspeaker(freq, amp, dly, xpos, ypos));
    }
    //some debugging here
    println("Tapered array window cos^"+wpower);
}

void drawProfile() {
    int wp = 100;
    int hp = 20;
    int xoff = 20;
    int yoff = h-20;
    int x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    stroke(255);
    for(int i=0; i<=wp; i++) {
        float pos = map(i,0,wp,0,1);
        float window = taper(pos);
        x1 = i; y1 = round(map(window,0,1,0,hp));
        line(xoff + x1, yoff - y1, xoff + x2, yoff - y2);
        x2 = x1; y2 = y1;
    }
}

float taper(float x) {
    float y;
    x = 0.5 - abs(x - 0.5);
    if(x > taperwidth) { 
        y = 1; 
    } else {
        x = x/taperwidth * PI;
        y = pow(.5*(1-cos(x)),wpower);
    }
    return y;
}

void draw() {
    background(50);

    //interactive virtual source position
    for (int e = 0; e < loudspeakers.size(); e++) {
        Loudspeaker u = (Loudspeaker)loudspeakers.get(e);
        //update loudspeaker delay
        int sign = 1; 
        if(mouseX < u.x) sign = -1; //positive sign makes a "focused source" when the listener is to the right
        else sign = 1;
        float dst = sqrt(pow(u.x-mouseX,2) + pow(u.y-mouseY,2));
        u.p = sign * dst / c; //travel time = distance over speed of propagation
        if(roundtime == 1) { u.p = 10*round(u.p/10); }
        u.att = 1;//sqrt(dst) / 10; //boost amplitude proportionally to distance. In 3d simulation, boost proportionally to square of distance.
    }
    buffer.beginDraw();
    for (int i = xpos/upsample; i< wd; i++) {
        for (int j = 0; j < hd; j++) {
            int f = 0; // virtual source pressure
            float d = 0;
            for (int e = 0; e < loudspeakers.size(); e++) {
                Loudspeaker u = (Loudspeaker)loudspeakers.get(e);
                d = sqrt(pow(i*upsample-u.x,2) + pow(j*upsample-u.y,2));
                switch(signaltype) {
                case 0: //sinusoid
                    f += int( 128/loudspeakers.size() + 4048 * 1/d * u.a * u.att * sin(2*PI * u.w * ( d - t - u.p )  ) );
                    break;
                case 1: //noise
                    f += int( 128/loudspeakers.size() + 2048 * 1.5/d * u.a * u.att * (noise(2 * u.w * ( d - t - u.p )  )-.5) );
                    break;
                case 2: //saw
                    float impulse = map((-u.w * ( d - t - u.p ))%1, 0,1, -1,1);
                    f += int( 128/loudspeakers.size() + 2048 * 1/d * u.a * u.att * impulse );
                    break;
                }
            }
            if(f < 0) f = 0;
            if(f > 255) f = 255;

            if(primarywave ==1) {
                int r = 0; // actual source pressure 
                d = sqrt(pow(i*upsample-mouseX,2) + pow(j*upsample-mouseY,2));
                //float phase = d/c;
                switch(signaltype) {
                case 0: //sinusoid
                    r += int( 124 + 2548/pow(d,.707) * sin(2*PI / wavelength * ( d - t )  ) );
                    break;
                case 1: //noise
                    r += int( 64 * 2048/d  * (noise(2 / wavelength * ( d - t )  )-.5) );
                    break;
                case 2: //saw
                    float impulse = map((-1/wavelength * ( d - t ))%1, 0,1, -1,1);
                    r += int( 128 * 255/d * impulse );
                    break;
                }
                if(r < 0) r = 0;
                if(r > 255) r = 255;

                buffer.pixels[j*wd + i] = color(r,f,0);
            }       
            else {
                buffer.pixels[j*wd + i] = color(f);
            }
        }
    }

    buffer.updatePixels();
    buffer.endDraw();
    //copy(buffer,0,0,wd,hd,0,0,w,h);
    //updatePixels();
    image(buffer, 0,0,w,h);
    drawProfile();
    drawText();
    for (int e = 0; e < loudspeakers.size(); e++) {
        Loudspeaker u = (Loudspeaker)loudspeakers.get(e);
        u.display();
    }  
    t += timestep;
}

class Loudspeaker {
    float w; //frequency rad/sec
    float a; //amplitude
    float p; //time delay
    float x; //position x
    float y; //position y
    float att; //distance attenuation
    Loudspeaker(float ww, float aa, float pp,  float xx, float yy) {
        w = ww;
        a = aa;
        p = pp;
        x = xx;
        y = yy;
    }
    void display() {
        image(lsicon, x - lsicon.width/2, y-lsicon.height/2);
    }
}

void drawText() {
  int margin = 20;
  
  textAlign(LEFT);
  textFont(fontA, 11);
  text("Tapering Profile:",margin,height-(margin+30));
  
  int lh = 20;
  int ln = 1;
  text("Loudspeakers: "+nf(num,1,0),margin,margin+lh*ln++);
  text("Spacing: "+dst,margin,margin+lh*ln++);
  text("Wavelength: "+wavelength,margin,margin+lh*ln++);
  text("Signal: "+ signallabel,margin,margin+lh*ln++);

}

void keyPressed() {
    if(keyCode == DOWN && dst > 7) dst-=2; //adjust loudspeaker spacing
    if(keyCode == UP && dst < 50) dst+=2;
    if(keyCode == LEFT && num > 4) num-=1; //adjust number of loudspeakers
    if(keyCode == RIGHT && num < 50) num+=1;
    if(key == '[' && wavelength > 8) wavelength-=2; //adjust frequency of signal
    if(key == ']' && wavelength < 100) wavelength+=2;
    if(key == 'r') randomize = 1 - randomize; //toggle randomized array spacing
    if(key == 't') roundtime = 1 - roundtime; //toggle phase offset rounding 
    if(key == 'p') primarywave = 1 - primarywave; //toggle primary wave
    if(key == 's') {
        signaltype = (signaltype+1)%numsignaltypes; //cycle signal type
        switch(signaltype) {
            case 0:
               signallabel = "Sine"; break;
            case 1:
               signallabel = "Noise"; break;
            case 2:
               signallabel = "Saw"; break;
        }
    }
               
    if(key == 'q' && taperwidth > 0.05) taperwidth-=.05; //adjust array tapering profile
    if(key == 'w' && taperwidth < .5) taperwidth+=.05;  
    if(key == '1' && upsample > 1) { 
        upsample -= 1; 
        initBuffer();
    } //adjust detail level
    if(key == '2' && upsample < 8) { 
        upsample += 1; 
        initBuffer();
    }

    initArray();
}

