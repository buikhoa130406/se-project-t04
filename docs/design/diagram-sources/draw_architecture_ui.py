from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from math import atan2, cos, sin, pi

ROOT = Path(__file__).parent / "output"
ROOT.mkdir(exist_ok=True)
FONTS = Path(r"C:\Windows\Fonts")
BLUE, LIGHT, TEXT, EDGE = "#2372A9", "#EBF4FB", "#182C3A", "#3B627D"
font = ImageFont.truetype(str(FONTS/"arial.ttf"), 25)
small = ImageFont.truetype(str(FONTS/"arial.ttf"), 21)
bold = ImageFont.truetype(str(FONTS/"arialbd.ttf"), 27)

class Diagram:
    def __init__(self, name, width=1400, height=520):
        self.name = name
        self.im = Image.new("RGB", (width,height), "white")
        self.draw = ImageDraw.Draw(self.im)

    def text(self, xy, s, face=font, fill=TEXT, anchor="mm"):
        self.draw.multiline_text(xy, s, font=face, fill=fill, anchor=anchor, align="center", spacing=6)

    def node(self, rect, title, sub="", accent=False):
        x,y,x2,y2=rect
        self.draw.rounded_rectangle(rect,radius=13,fill=BLUE if accent else LIGHT,outline=BLUE,width=3)
        c=(x+x2)/2; mid=(y+y2)/2
        self.text((c,mid-17 if sub else mid), title, bold, "white" if accent else TEXT)
        if sub:
            self.text((c,mid+20 if "\n" in sub else mid+18),sub,small,"white" if accent else EDGE)

    def group(self, rect, label):
        x,y,_,_=rect
        self.draw.rounded_rectangle(rect, radius=16, outline="#ABBDD0", width=3,fill="#F8FAFD")
        self.draw.text((x+17,y+12),label,fill=EDGE,font=small)

    def arrow(self, points, label="", at=None):
        self.draw.line(points, fill=EDGE, width=4, joint="curve")
        (x1,y1),(x,y)=points[-2:]
        ang=atan2(y-y1,x-x1)
        self.draw.polygon([(x,y),(x-16*cos(ang-pi/6),y-16*sin(ang-pi/6)),(x-16*cos(ang+pi/6),y-16*sin(ang+pi/6))], fill=EDGE)
        if label and at:
            bx=self.draw.textbbox(at,label,font=small,anchor="mm")
            self.draw.rectangle((bx[0]-5,bx[1]-3,bx[2]+5,bx[3]+3),fill="white")
            self.text(at,label,small,EDGE)

    def save(self):
        self.im.save(ROOT/f"{self.name}.png")

d=Diagram("c4-context",height=350)
for x,label,sub in [(45,"Guest","Search and browse"),(515,"Player","Reserve and cancel"),(985,"Facility owner","Manage courts and schedule")]:
    d.node((x,15,x+370,110),label,sub)
    d.arrow([(x+185,110),(x+185,167),(700,167),(700,230)])
d.node((420,230,980,337),"CourtConnect","Shared court schedule and in-app updates",True)
d.save()

d=Diagram("c4-container",height=410)
d.group((344,35,1380,379),"Cloud Linux environment")
d.node((20,155,249,270),"Browser","Customer or owner")
d.node((365,151,606,270),"React SPA","Responsive web UI")
d.node((711,117,1030,303),"Express backend","REST API and ReleaseJob\nSame Node.js process",True)
d.node((1138,151,1358,270),"PostgreSQL","Booking and schedule data")
d.arrow([(249,211),(365,211)],"HTTPS",(301,185))
d.arrow([(606,211),(711,211)],"REST",(659,185))
d.arrow([(1030,211),(1138,211)],"SQL",(1084,185))
d.save()

d=Diagram("c4-component",height=590)
d.group((180,78,1380,580),"Node.js and Express process")
d.node((12,10,269,66),"React SPA")
d.node((267,124,850,208),"Auth and RBAC middleware")
d.node((1010,118,1330,212),"ReleaseJob","Scheduled in this process")
d.arrow([(140,66),(140,165),(267,165)])
modules=[("Auth",196),("Facility search",431),("Booking and hold",666),("Owner schedule",901),("Notifications",1136)]
for label,x in modules:
    d.node((x,286,x+219,374),label,accent=(x==666))
    d.arrow([(559,208),(559,238),(x+110,238),(x+110,286)])
    d.arrow([(x+110,374),(x+110,424),(765,424),(765,467)])
d.arrow([(1170,212),(1170,261),(843,261),(843,286)])
d.node((482,467,1048,554),"Repositories","Transaction and SQL / Pool to PostgreSQL")
d.save()

d=Diagram("c4-deployment",height=470)
d.group((367,24,1380,318),"Cloud Linux server")
d.node((18,120,258,246),"User device","Chrome or Safari")
d.node((392,121,650,246),"Nginx","React files and API proxy")
d.node((763,104,1065,264),"Node.js process","Express API + ReleaseJob",True)
d.node((1170,120,1359,246),"PostgreSQL","Shared schedule")
d.arrow([(258,183),(392,183)],"HTTPS",(329,152))
d.arrow([(650,183),(763,183)],"/api",(708,153))
d.arrow([(1065,183),(1170,183)],"SQL",(1116,153))
d.node((244,352,615,451),"GitHub repository","Push or pull request")
d.node((785,352,1156,451),"GitHub Actions","Jest tests")
d.arrow([(615,401),(785,401)],"CI",(700,371))
d.save()

d=Diagram("ui-flow",height=437)
for y,labs in [(29,["UI-01 Home","UI-02 Search","UI-05 Details","UI-06 Select slots","UI-07 Hold","UI-08 Confirmed"]),
               (169,["UI-03 Sign in","UI-04 Register","UI-01 Home","UI-09 Bookings","UI-10 Cancel","UI-11 Alerts"]),
               (309,["UI-12 Owner","UI-13 Facilities","UI-14 Schedule","UI-15 In-person"])]:
    for i,label in enumerate(labs):
        x=22+i*230
        d.node((x,y,x+205,y+78),label,accent=(label in ["UI-07 Hold","UI-12 Owner"]))
        if y==29 and i:
            d.arrow([(x-25,y+39),(x,y+39)])
for at,s in [((700,135),"Guest at Proceed to booking → sign in → return to Home and select again"),
             ((700,274),"Bookings → details / cancellation or in-app notifications"),
             ((700,411),"Owner dashboard → facility management, schedule changes or in-person booking")]:
    d.text(at,s,small,EDGE)
d.save()
