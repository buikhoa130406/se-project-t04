from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
qa=Path(__file__).parent / "output"
qa.mkdir(exist_ok=True)

W,H=2000,1580
im=Image.new("RGB",(W,H),"white")
dr=ImageDraw.Draw(im)
F=Path(r"C:\Windows\Fonts")
fb=ImageFont.truetype(str(F/"segoeuib.ttf"),31)
ft=ImageFont.truetype(str(F/"segoeui.ttf"),26)
edge="#375776"
def box(x,y,name,fields,w=540,h=224):
    dr.rectangle((x,y,x+w,y+h),fill="#F1F5FA",outline="#205587",width=3)
    dr.rectangle((x,y,x+w,y+52),fill="#DBE7F5",outline="#205587",width=2)
    dr.text((x+18,y+10),name,font=fb,fill="#152B42")
    for j,s in enumerate(fields): dr.text((x+18,y+66+j*36),s,font=ft,fill="#152B42")
def route(points,label,where):
    dr.line(points,fill=edge,width=3,joint="curve")
    x,y=points[-1]
    dr.ellipse((x-5,y-5,x+5,y+5),fill=edge)
    bb=dr.textbbox(where,label,font=ft,anchor="mm")
    dr.rectangle((bb[0]-5,bb[1]-3,bb[2]+5,bb[3]+3),fill="white")
    dr.text(where,label,font=ft,anchor="mm",fill=edge)
rows=[35,420,805,1190]
cols=[60,730,1400]
# Labels give parent-to-child multiplicities. Detailed columns follow in section 5.2.
items=[
(cols[0],rows[0],"sport",["PK id","UQ name"]),
(cols[1],rows[0],"app_user",["PK id · UQ email · UQ phone","role · password_hash"]),
(cols[2],rows[0],"amenity",["PK id","UQ name"]),
(cols[0],rows[1],"operating_hours",["PK/FK facility_id","PK day_of_week","open_time · close_time"]),
(cols[1],rows[1],"facility",["PK id · FK owner_id","FK sport_id · name","district · address"]),
(cols[2],rows[1],"facility_amenity",["PK/FK facility_id","PK/FK amenity_id"]),
(cols[0],rows[2],"court",["PK id · FK facility_id","status · deleted_at","UQ facility_id + name"]),
(cols[1],rows[2],"hold",["PK id · FK user_id / facility_id","source · status · expires_at","release_failed_at"]),
(cols[2],rows[2],"booking",["PK id · UQ/FK hold_id","FK user_id / facility_id","source · status · cancel_reason"]),
(cols[0],rows[3],"court_price",["PK/FK court_id","PK effective_from","amount_per_slot"]),
(cols[1],rows[3],"schedule_entry",["PK id · FK court/facility","FK hold/booking/blocked_by","range · unit_price · is_active"]),
(cols[2],rows[3],"notification",["PK id · FK user/booking","reason · message · is_read","affected_items"]),
]
for x,y,n,f in items: box(x,y,n,f)
route([(1000,259),(1000,420)],"1 owns 0..*",(1000,340))
route([(600,147),(650,147),(650,350),(850,350),(850,420)],"1 classifies 0..*",(645,310))
route([(1400,534),(1270,534)],"0..* at 1",(1335,512))
route([(1670,259),(1670,420)],"1 used by 0..*",(1670,340))
route([(730,534),(600,534)],"1 has 0..*",(665,512))
route([(850,644),(850,700),(330,700),(330,805)],"1 has 1..*",(560,678))
route([(1000,644),(1000,805)],"1 has 0..*",(1000,718))
route([(1270,910),(1400,910)],"1 : 0..1",(1335,880))
route([(330,1029),(330,1190)],"1 has 1..*",(330,1105))
route([(1000,1029),(1000,1190)],"1 reserves 0..*",(1000,1105))
route([(1670,1029),(1670,1190)],"1 triggers 0..*",(1670,1105))
route([(600,940),(660,940),(660,1285),(730,1285)],"1 has 0..*",(663,1135))
route([(1510,1029),(1510,1140),(1220,1140),(1220,1190)],"1 covers 0..*",(1345,1118))
dr.text((60,1470),"PK primary key   FK foreign key   UQ unique key",font=ft,fill="#152B42")
dr.text((60,1510),"User links to holds, bookings, blocked ranges and notices also follow the foreign keys in section 5.2.",font=ft,fill="#152B42")
im.save(qa/"erd-overview.png")
