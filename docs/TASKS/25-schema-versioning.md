# Task 25: Schema versioning (#4)

**Status:** Open
**Branch:** `fix/task25-schema-versioning`
**Followup:** #4 (pre-TestFlight blocker)

## Doel

Leg een SwiftData VersionedSchema baseline vast zodat we na TestFlight veilig migraties kunnen toevoegen.

## Wat te doen

1. Definieer `SchemaV1` als `VersionedSchema` die de huidige `ConversationEntity` + `MessageEntity` wrapt
2. Maak `HermesMigrationPlan: SchemaMigrationPlan` met `schemas = [SchemaV1.self]` (geen migration stages — alleen de baseline)
3. Update `ModelStack.buildContainer()` om het migration plan door te geven aan `ModelConfiguration`
4. Voeg test toe in `ModelStackTests.swift` dat de container bouwt met het versioned schema

## Files owned (exclusief)

- `Sources/HermesMac/Core/Persistence/ConversationEntity.swift`
- `Sources/HermesMac/Core/Persistence/MessageEntity.swift`
- `Sources/HermesMac/Core/Persistence/ModelStack.swift`
- `Tests/HermesMacTests/ModelStackTests.swift`

## Acceptatiecriteria

- `SchemaV1` bestaat als `VersionedSchema` met `versionIdentifier = Schema.Version(1, 0, 0)`
- `HermesMigrationPlan` bestaat met `schemas = [SchemaV1.self]`, leeg stages array
- Container bouwt correct met migration plan
- Bestaande tests blijven slagen, nieuwe test verifieert versioned schema
