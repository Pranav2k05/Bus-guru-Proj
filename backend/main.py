import uvicorn
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float, ForeignKey, JSON
from sqlalchemy.orm import sessionmaker, Session, declarative_base, relationship
from pydantic import BaseModel, ConfigDict
from passlib.context import CryptContext
from datetime import datetime
from typing import List, Optional
import random
import re
import requests
import os

# --- YOUR GROQ KEY HERE ---
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
db_path = os.path.abspath("bengaluru_bus.db")
DATABASE_URL = f"sqlite:///{db_path}"

# --- DB SETUP ---
Base = declarative_base()
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# --- Models ---
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    hashed_password = Column(String)

class Bus(Base):
    __tablename__ = "buses"
    id = Column(Integer, primary_key=True, index=True)
    bus_name = Column(String)
    route_name = Column(String)
    start_stop = Column(String)
    end_stop = Column(String)
    departure_time = Column(String)
    fare = Column(Float)
    total_seats = Column(Integer)
    route_coords = Column(JSON)
    stops = Column(JSON)

class Booking(Base):
    __tablename__ = "bookings"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    bus_id = Column(Integer, ForeignKey("buses.id"))
    seats_booked = Column(Integer)
    total_price = Column(Float)
    booking_date = Column(String)
    validated = Column(Integer, default=0)  # NEW!
    user = relationship("User")
    bus = relationship("Bus")

class UserCreate(BaseModel):
    email: str
    password: str
    name: str

class BusOut(BaseModel):
    id: int
    bus_name: str
    route_name: str
    start_stop: str
    end_stop: str
    departure_time: str
    fare: float
    total_seats: int
    route_coords: List[List[float]]
    stops: List[str]
    model_config = ConfigDict(from_attributes=True)

class BookingCreate(BaseModel):
    bus_id: int
    seats: int

class ChatRequest(BaseModel):
    message: str
    token: Optional[str] = None
    prev_lang: Optional[str] = None

class ValidationRequest(BaseModel):
    booking_id: int

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def detect_lang(text):
    if re.search(r'[\u0C80-\u0CFF]', text): return "kn"
    if re.search(r'[\u0900-\u097F]', text): return "hi"
    return "en"

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
def seed_data():
    print("\n=== [BACKEND] Startup: Creating tables and seeding buses ===")
    Base.metadata.create_all(bind=engine)
    print("=== [BACKEND] Tables created ===")
    db = SessionLocal()
    try:
        db.query(Bus).delete()
        db.commit()
        locs = {
            "Majestic": [12.9767, 77.5713], "Whitefield": [12.9698, 77.7499], "Silk Board": [12.9177, 77.6238],
            "Airport": [13.1986, 77.7066], "Electronic City": [12.8452, 77.6602], "Banashankari": [12.9255, 77.5468],
            "Hebbal": [13.0359, 77.5970], "Indiranagar": [12.9719, 77.6412], "Marathahalli": [12.9591, 77.6974],
            "Kengeri": [12.9176, 77.4833], "HSR Layout": [12.9121, 77.6446], "Koramangala": [12.9352, 77.6245],
            "Shivajinagar": [12.9857, 77.6057], "Yelahanka": [13.1007, 77.5963], "Mekhri Circle": [13.0136, 77.5804],
            "Domlur": [12.9609, 77.6387], "Richmond Circle": [12.9645, 77.5968], "Corporation": [12.9679, 77.5881]
        }
        keys = list(locs.keys())
        routes = []
        count = 0
        for start in keys:
            for end in keys:
                if start == end: continue
                mid1 = keys[random.randint(0, len(keys)-1)]
                mid2 = keys[random.randint(0, len(keys)-1)]
                path_stops = [str(start), str(mid1), str(mid2), str(end)]
                clean_stops = []
                [clean_stops.append(x) for x in path_stops if x not in clean_stops]
                if len(clean_stops) < 2: clean_stops = [str(start), "Town Hall", str(end)]
                path_coords = [locs.get(s, [12.9716, 77.5946]) for s in clean_stops]
                is_ac = random.choice([True, False])
                bus_num = f"KIA-{random.randint(1,15)}" if "Airport" in end or "Airport" in start else f"3{random.randint(0,9)}0-{random.choice(['E','C','K'])}"
                fare = 265.0 if "Airport" in str(bus_num) else (85.0 if is_ac else 25.0)
                routes.append(Bus(
                    bus_name=bus_num, route_name=f"{start} - {end}",
                    start_stop=str(start), end_stop=str(end),
                    departure_time=f"{random.randint(6,21):02d}:{random.choice(['00','15','30','45'])}",
                    fare=fare, total_seats=45, route_coords=path_coords, stops=clean_stops
                ))
                count += 1
                if count > 60: break
            if count > 60: break
        db.add_all(routes)
        db.commit()
        print(f"[BACKEND] Seeded {len(routes)} routes.")
    except Exception as e:
        print(f"❌ DB ERROR: {e}")
    finally:
        db.close()

@app.post("/auth/signup")
def signup(user: UserCreate, db: Session = Depends(get_db)):
    print(f"[REGISTER] {user.email}")
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email taken")
    db.add(User(email=user.email, name=user.name, hashed_password=pwd_context.hash(user.password)))
    db.commit()
    print(f"  Registered successfully.")
    return {"message": "Success"}

@app.post("/auth/login")
def login(user_in: UserCreate, db: Session = Depends(get_db)):
    print(f"[LOGIN] {user_in.email}")
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not pwd_context.verify(user_in.password, user.hashed_password):
        print(f"  Failed login (not found or bad password)")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    print(f"  Login OK")
    return {"access_token": user.email, "token_type": "bearer", "user_name": user.name, "user_email": user.email}

@app.get("/buses", response_model=List[BusOut])
def get_buses(db: Session = Depends(get_db)):
    print("[BUSES] List requested")
    return db.query(Bus).all()

@app.get("/stops")
def get_stops(db: Session = Depends(get_db)):
    buses = db.query(Bus).all()
    stops = set()
    for b in buses:
        stops.add(b.start_stop)
        stops.add(b.end_stop)
    print(f"[STOPS] Total: {len(stops)}")
    return sorted(list(stops))

@app.post("/book")
def book_seat(booking: BookingCreate, token: str, db: Session = Depends(get_db)):
    print(f"[BOOKING] user={token}, bus_id={booking.bus_id}, seats={booking.seats}")
    user = db.query(User).filter(User.email == token).first()
    if not user: raise HTTPException(status_code=401, detail="Invalid token")
    bus = db.query(Bus).filter(Bus.id == booking.bus_id).first()
    if not bus: raise HTTPException(status_code=404, detail="Bus not found")
    if bus.total_seats < booking.seats: raise HTTPException(status_code=400, detail="Not enough seats!")
    bus.total_seats -= booking.seats
    new_booking = Booking(user_id=user.id, bus_id=bus.id, seats_booked=booking.seats, total_price=bus.fare * booking.seats, booking_date=datetime.now().strftime("%Y-%m-%d %H:%M"))
    db.add(new_booking)
    db.commit()
    db.refresh(new_booking)
    print(f"  Booking success: #{new_booking.id}")
    return {
        "id": new_booking.id,
        "seats_booked": new_booking.seats_booked,
        "total_price": new_booking.total_price,
        "booking_date": new_booking.booking_date,
        "bus_name": bus.bus_name,
        "route_name": bus.route_name,
        "user_email": user.email,
        "bus_id": bus.id,
    }

@app.get("/my-bookings")
def get_my_bookings(token: str, db: Session = Depends(get_db)):
    print(f"[MY-BOOKINGS] {token}")
    user = db.query(User).filter(User.email == token).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    bookings = db.query(Booking).filter(Booking.user_id == user.id).all()
    results = []
    for b in bookings:
        bus = db.query(Bus).filter(Bus.id == b.bus_id).first()
        if bus:
            results.append({
                "id": b.id,
                "seats_booked": b.seats_booked,
                "total_price": b.total_price,
                "booking_date": b.booking_date,
                "bus_name": bus.bus_name,
                "route_name": bus.route_name,
                "user_email": user.email,
                "bus_id": bus.id,
                "validated": (b.validated == 1),  # NEW!
            })
    print(f"  Found: {len(results)} bookings.")
    return results

@app.post("/validate-ticket")
def validate(req: ValidationRequest, db: Session = Depends(get_db)):
    print(f"[VALIDATE-TICKET] booking_id={req.booking_id}")
    booking = db.query(Booking).filter(Booking.id == req.booking_id).first()
    if not booking:
        print("  Not found/INVALID.")
        return {"status": "INVALID", "message": "Fake Ticket!"}
    if booking.validated == 1:
        return {"status": "ALREADY_VALIDATED", "message": "This ticket was already validated."}
    booking.validated = 1
    db.commit()
    user = db.query(User).filter(User.id == booking.user_id).first()
    return {
        "status": "VALID",
        "message": f"Verified!\nPassenger: {user.name}\nBus: {booking.bus.bus_name}",
    }

@app.post("/chat")
async def chat_bot(req: ChatRequest, db: Session = Depends(get_db)):
    print(f"[CHAT] {req.message} (token={req.token})")
    user_name, user_email, booking_history = "Guest", "", []
    tickets_str = "No tickets booked."
    if req.token:
        user = db.query(User).filter(User.email == req.token).first()
        if user:
            user_name = user.name
            user_email = user.email
            bookings = db.query(Booking).filter(Booking.user_id == user.id).all()
            if bookings:
                booking_history = [
                    {
                        "bus": db.query(Bus).filter(Bus.id == b.bus_id).first().bus_name if db.query(Bus).filter(Bus.id == b.bus_id).first() else "",
                        "route": db.query(Bus).filter(Bus.id == b.bus_id).first().route_name if db.query(Bus).filter(Bus.id == b.bus_id).first() else "",
                        "date": b.booking_date,
                        "seats": b.seats_booked,
                        "ticket_id": b.id,
                    }
                    for b in bookings[-3:]
                ]
                tickets_str = "\n".join(
                    [f"Ticket #{t['ticket_id']}: {t['bus']} ({t['route']}) on {t['date']} [{t['seats']} seats]" for t in booking_history]
                )
    buses = db.query(Bus).all()
    bus_status = [f"{b.bus_name}: {b.start_stop} to {b.end_stop} @ {b.departure_time}" for b in buses[:6]]
    cur_lang = detect_lang(req.message)
    prev_lang = req.prev_lang or cur_lang
    lang = cur_lang if cur_lang != prev_lang else prev_lang
    lang_name = {"kn": "Kannada", "hi": "Hindi", "en": "English"}[lang]
    msg_lc = req.message.lower()
    is_sos = ("sos" in msg_lc or "emergency" in msg_lc)

    prompt = f"""
You are Bus Guru, a multilingual assistant for BMTC-Bengaluru.
User: {user_name if user_name else 'Guest'} ({user_email if user_email else 'No Email'})
Latest tickets:
{tickets_str}
Live bus status:
{', '.join(bus_status[:3])}
IMPORTANT:
- If the user types in {lang_name}, reply ONLY in {lang_name} (do not mix any other language).
- Greet by user's name in every reply.
- If user asks for "ticket", "booking", "my ticket", show their last ticket (details above).
- If input is 'SOS' or 'Emergency', reply with BMTC helpline and instructions in {lang_name}.
- If route is mentioned, reply with matching buses (buses above).
User Message: "{req.message}"
    """
    try:
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"}
        data = {"model": "llama-3.1-8b-instant", "messages": [{"role": "user", "content": prompt}], "temperature": 0.7}
        response = requests.post(url, headers=headers, json=data, timeout=10)
        if response.status_code == 200:
            reply = response.json()['choices'][0]['message']['content']
            return {"response": str(reply or ""), "lang": str(lang or "en")}
        else:
            print("[GroqAPI]", response.status_code, response.text)
    except Exception as e:
        print("Groq Error:", e)

    if "ticket" in msg_lc or "booking" in msg_lc:
        if booking_history:
            if lang == "kn":
                tickets_list = "\n".join([f"{t['bus']} ({t['route']}) ನಲ್ಲಿ {t['date']} [{t['seats']} ಸ್ಥಾನಗಳು]" for t in booking_history])
                return {"response": f"ಪ್ರಿಯ {user_name}, ನಿಮ್ಮ ಟಿಕೆಟ್ ಇಲ್ಲಿವೆ:\n{tickets_list}", "lang": "kn"}
            if lang == "hi":
                tickets_list = "\n".join([f"{t['bus']} ({t['route']}) पर {t['date']} [{t['seats']} सीटें]" for t in booking_history])
                return {"response": f"{user_name} जी, आपकी टिकटें:\n{tickets_list}", "lang": "hi"}
            return {"response": f"{user_name}, here are your recent tickets:\n{tickets_str}", "lang": "en"}
        else:
            if lang == "kn":
                return {"response": f"{user_name}님, ನೀವು ಯಾವುದೇ ಟಿಕೆಟ್ ಬುಕ್ ಮಾಡಿಲ್ಲ.", "lang": "kn"}
            if lang == "hi":
                return {"response": f"{user_name} जी, आपकी कोई टिकट नहीं मिली।", "lang": "hi"}
            return {"response": f"{user_name}, you have no tickets.", "lang": "en"}

    if is_sos:
        if lang == "kn":
            return {"response": "BMTC ತ್ವರಿತ ಸಹಾಯ: 080-22483777. ಪೊಲೀಸ್‌ಗೆ ಕರೆ ಮಾಡಿ: 100. ನಿಮ್ಮ ಟಿಕೆಟ್ ಮತ್ತು ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳಿ.", "lang": "kn"}
        if lang == "hi":
            return {"response": "बीएमटीसी आपातकालीन: 080-22483777. पुलिस कॉल करें: 100. अपना टिकट और स्थान साझा करें.", "lang": "hi"}
        return {"response": "BMTC Emergency: Call 080-22483777, police 100. Share your ticket and location.", "lang": "en"}

    if lang == "kn":
        return {"response": f"ನಮಸ್ಕಾರ {user_name}! Bus Guru ಪ್ರಸ್ತುತ ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದೆ. ದಯವಿಟ್ಟು Plan Journey ಅಥವಾ My Tickets ಬಳಸಿ.", "lang": "kn"}
    if lang == "hi":
        return {"response": f"नमस्ते {user_name}! Bus Guru फिलहाल ऑफलाइन है। कृपया Plan Journey या My Tickets देखें।", "lang": "hi"}
    return {"response": f"Hi {user_name}, Guru AI is currently offline. Please use Plan Journey and My Tickets while we restore service.", "lang": "en"}

if __name__ == "__main__":
    print("[Server] Running on 0.0.0.0:8000 ...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
