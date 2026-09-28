"""Reset and seed the EV charging manager with demo drivers and 15 route stations."""

import sqlite3

from app.database import create_tables, get_connection

DEMO_USERS = [
    (1, "Aarav Shah"),
    (2, "Anaya Patel"),
    (3, "Kabir Mehta"),
    (4, "Isha Desai"),
]

DEMO_VEHICLES = [
    (1, 1, "Tata Nexon EV", "MH 02 AB 4821", 40.5),
    (2, 2, "MG ZS EV", "MH 04 CD 7392", 50.3),
    (3, 3, "Mahindra XEV 9e", "MH 12 EF 1658", 59.0),
    (4, 4, "Hyundai Kona", "MH 01 GH 9046", 39.2),
]

STATIONS = [
    ("Mumbai Central ChargeHub", "Mumbai", "Mumbai → Pune", 19.0760, 72.8777, 5),
    ("Panvel Green Charge", "Panvel", "Mumbai → Pune", 18.9894, 73.1175, 5),
    ("Khopoli Highway Charge", "Khopoli", "Mumbai → Pune", 18.7870, 73.3450, 5),
    ("Khandala View Charge", "Khandala", "Mumbai → Pune", 18.7537, 73.3762, 5),
    ("Lonavala Green Charge", "Lonavala", "Mumbai → Pune", 18.7546, 73.4062, 5),
    ("Pune Central ChargeHub", "Pune", "Mumbai → Pune", 18.5204, 73.8567, 5),
    ("Mumbai West ChargeHub", "Mumbai", "Mumbai → Surat", 19.0760, 72.8777, 4),
    ("Bhiwandi Highway Charge", "Bhiwandi", "Mumbai → Surat", 19.2813, 73.0483, 4),
    ("Palghar Green Charge", "Palghar", "Mumbai → Surat", 19.6967, 72.7699, 4),
    ("Vapi Highway Charge", "Vapi", "Mumbai → Surat", 20.3710, 72.9049, 4),
    ("Valsad Green Charge", "Valsad", "Mumbai → Surat", 20.5992, 72.9342, 4),
    ("Surat Central ChargeHub", "Surat", "Mumbai → Surat", 21.1702, 72.8311, 5),
    ("Mumbai Harbour ChargeHub", "Mumbai", "Mumbai → Goa", 19.0760, 72.8777, 4),
    ("Panvel Coastal Charge", "Panvel", "Mumbai → Goa", 18.9894, 73.1175, 4),
    ("Mahad Green Charge", "Mahad", "Mumbai → Goa", 18.0833, 73.4167, 4),
    ("Chiplun Highway Charge", "Chiplun", "Mumbai → Goa", 17.5334, 73.5168, 4),
    ("Ratnagiri Coastal Charge", "Ratnagiri", "Mumbai → Goa", 16.9902, 73.3120, 4),
    ("Goa Central ChargeHub", "Goa", "Mumbai → Goa", 15.2993, 74.1240, 5),
]


def seed() -> None:
    create_tables()
    connection = get_connection()
    try:
        connection.execute("BEGIN IMMEDIATE")
        connection.execute("DELETE FROM bookings")
        connection.execute("DELETE FROM slots")
        connection.execute("DELETE FROM stations")
        connection.execute("DELETE FROM vehicles")
        connection.execute("DELETE FROM users")
        connection.executemany("INSERT INTO users (id, name) VALUES (?, ?)", DEMO_USERS)
        connection.executemany(
            """INSERT INTO vehicles
               (id, user_id, model, plate, battery_capacity)
               VALUES (?, ?, ?, ?, ?)""",
            DEMO_VEHICLES,
        )
        for name, location, route, latitude, longitude, total_slots in STATIONS:
            cursor = connection.execute(
                """INSERT INTO stations
                   (name, location, route, latitude, longitude, total_slots)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (name, location, route, latitude, longitude, total_slots),
            )
            connection.executemany(
                "INSERT INTO slots (station_id, status) VALUES (?, 'available')",
                [(cursor.lastrowid,) for _ in range(total_slots)],
            )
        connection.commit()
    except sqlite3.Error:
        connection.rollback()
        raise
    finally:
        connection.close()

    town_count = len({station[1] for station in STATIONS})
    print(
        f"Seeded {len(DEMO_USERS)} demo users, {len(DEMO_VEHICLES)} vehicles, "
        f"{len(STATIONS)} route-specific stations across {town_count} towns."
    )
    for route in ("Mumbai → Pune", "Mumbai → Surat", "Mumbai → Goa"):
        towns = [station[1] for station in STATIONS if station[2] == route]
        print(f"{route.replace('→', 'to')}: {', '.join(towns)}")
    print("Station locations match the route-to-coordinate town names used in frontend/mobile.html.")


if __name__ == "__main__":
    seed()
