from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from math import atan2, cos, sin, pi

qa = Path(__file__).parent / "output"
qa.mkdir(exist_ok=True)
font_paths = Path(r"C:\Windows\Fonts")
def font(size, bold=False):
    return ImageFont.truetype(str(font_paths / ("segoeuib.ttf" if bold else "segoeui.ttf")), size)

def body(size):
    img = Image.new("RGB", size, "#FFFFFF")
    return img, ImageDraw.Draw(img)

blue = "#205587"
ink = "#152B42"
line = "#375776"

def box(draw, x, y, name, members="", w=360, h=100, shade="#EFF5FC"):
    draw.rounded_rectangle((x,y,x+w,y+h), radius=12, fill=shade, outline=blue, width=3)
    if members:
        draw.line((x,y+49,x+w,y+49), fill=blue, width=2)
        draw.text((x+w/2,y+26), name, font=font(28,True), fill=ink, anchor="mm")
        draw.text((x+w/2,y+(h+49)/2), members, font=font(19 if len(members)>38 else 22), fill=ink, anchor="mm")
    else:
        draw.text((x+w/2,y+h/2), name, font=font(27,True), fill=ink, anchor="mm")

def point(draw, xy, angle):
    endx,endy=xy
    tip = [(endx,endy), (endx-15*cos(angle-pi/6),endy-15*sin(angle-pi/6)),
                         (endx-15*cos(angle+pi/6),endy-15*sin(angle+pi/6))]
    draw.polygon(tip,fill=line)

def connector(draw, points, label="", loc=None, composition=False, label_size=22):
    draw.line(points,fill=line,width=3,joint="curve")
    (x,y),(u,v)=points[-2:]
    point(draw,(u,v),atan2(v-y,u-x))
    if composition:
        (x,y),(u,v)=points[:2]
        a=atan2(v-y,u-x)
        p=[(x,y),(x+10*cos(a)+6*sin(a),y+10*sin(a)-6*cos(a)),
                  (x+20*cos(a),y+20*sin(a)),(x+10*cos(a)-6*sin(a),y+10*sin(a)+6*cos(a))]
        draw.polygon(p,fill=line)
    if label and loc:
        ft=font(label_size)
        bbox=draw.textbbox(loc,label,font=ft,anchor="mm")
        draw.rectangle((bbox[0]-5,bbox[1]-2,bbox[2]+5,bbox[3]+2),fill="white")
        draw.text(loc,label,font=ft,fill=ink,anchor="mm")

entity, de = body((1810,1220))
layout = [
    (100,52,"User","id · role · email · phone"),
    (710,52,"Facility","ownerId · sportType · amenities"),
    (1330,52,"OperatingHours","dayOfWeek · openTime · closeTime"),
    (100,385,"SlotHold","facilityId · userId · expiresAt"),
    (710,385,"Booking","facilityId · userId · status"),
    (1330,385,"Court","facilityId · courtCode · isActive"),
    (100,775,"HoldSlotItem","holdId · courtId · slot interval"),
    (710,775,"BookingItem","bookingId · courtId · slot interval"),
    (1330,775,"ScheduleBlock","courtId · ownerId · blocked interval"),
    (710,1070,"Notification","bookingId · isRead · affectedItems"),
]
for item in layout:
    box(de,*item)
connector(de,[(460,102),(710,102)],"1 owns 0..*",(585,82))
connector(de,[(1070,102),(1330,102)],"1 has 1..*",(1200,82),composition=True)
connector(de,[(210,152),(210,385)],"1 creates 0..*",(210,283))
connector(de,[(435,152),(435,191),(775,191),(775,385)],"1 places 0..*",(594,172))
connector(de,[(729,152),(729,260),(365,260),(365,385)],"1 scopes 0..*",(548,241))
connector(de,[(956,152),(956,385)],"1 receives 0..*",(956,299))
connector(de,[(1070,132),(1240,132),(1240,338),(1380,338),(1380,385)],
          "1 contains 1..*",(1282,226),composition=True)
connector(de,[(230,485),(230,775)],"1 holds 1..*",(230,632),composition=True)
connector(de,[(806,485),(806,775)],"1 contains 1..*",(799,721),composition=True)
connector(de,[(1366,485),(1366,540),(445,540),(445,775)],"1 locates 0..*",(604,521))
connector(de,[(1470,485),(1470,657),(1010,657),(1010,775)],"1 locates 0..*",(1248,639))
connector(de,[(1622,485),(1622,775)],"1 has 0..*",(1622,674))
connector(de,[(100,124),(50,124),(50,1122),(710,1122)],"1 receives 0..*",(363,1104))
connector(de,[(1070,462),(1132,462),(1132,1122),(1070,1122)],
          "0..1 triggers 0..*",(1244,1018))
entity.save(qa/"class-entities.png")

services, ds = body((1810,702))
box(ds,35,44,"OwnerScheduleService","ownership · schedule changes",w=410,h=100)
box(ds,35,417,"BookingService","shared hold and booking operations",w=410,h=100)
box(ds,1260,34,"ScheduleBlock","",w=450,h=79)
box(ds,1260,176,"Notification","",w=450,h=79)
box(ds,1260,326,"Booking","",w=450,h=79)
box(ds,1260,540,"SlotHold","",w=450,h=79)
connector(ds,[(445,64),(1260,64)],"manages schedule blocks",(810,44))
connector(ds,[(445,104),(623,104),(623,215),(1260,215)],"creates cancellation notices",(929,194))
connector(ds,[(445,132),(530,132),(530,343),(1260,343)],"creates direct bookings and cancels affected ones",(904,320))
connector(ds,[(259,144),(259,417)],"reuses hold and confirm",(259,285))
connector(ds,[(445,447),(1040,447),(1040,384),(1260,384)],"confirms and cancels",(810,424))
connector(ds,[(445,497),(880,497),(880,581),(1260,581)],"creates, expires and releases",(1055,560))
services.save(qa/"class-services.png")
