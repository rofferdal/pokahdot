# Inline Playing Card Value Component

## 1. Objective

Provide a lightweight, inline textual representation of playing cards in a command-line interface (CLI). The format must remain compact and clear without relying on multi-line ASCII graphics.

## 2. Core Format Definition

Every card must be rendered dynamically as a single, contiguous string combining its alphanumeric rank and corresponding Unicode suit symbol in this exact sequence:

```text
[Rank][Suit]
```

### 2.1 Card Ranks

- Numeric values: `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `10`
- Face values: `J` (Jack), `Q` (Queen), `K` (King), `A` (Ace)

### 2.2 Card Suits (Unicode)

The implementation must map the standard card suits to their canonical Unicode characters:

- Spades: `♠` (`U+2660`)
- Hearts: `♥` (`U+2665`)
- Diamonds: `♦` (`U+2666`)
- Clubs: `♣` (`U+2663`)

## 3. Collection Display Rules

When multiple cards are presented horizontally:

- Separate each card with a space, a vertical bar, and another space (` | `).
- Wrap the collection in square brackets with inner spacing (`[ ` and ` ]`).

Template:

```text
"[ " + Card1 + " | " + Card2 + " | " + CardN + " ]"
```

## 4. Target Output Examples

- Single card (Ace of Spades): `A♠`
- Single card (Ten of Hearts): `10♥`
- Three-card collection: `[ A♠ | 10♥ | K♦ ]`
- Five-card collection: `[ 2♣ | 7♦ | J♠ | Q♥ | A♣ ]`

## 5. Constraints and Compliance

- **Encoding:** The host shell or terminal must support UTF-8 encoding to display the Unicode suit glyphs without corruption, such as rendering them as `?` or replacement characters.
- **Sizing:** The application must not hardcode padding based on fixed string lengths. The rank `10` occupies two character positions, while every other rank occupies one; spacing must therefore be calculated dynamically.
