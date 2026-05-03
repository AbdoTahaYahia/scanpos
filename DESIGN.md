---
name: Organic Minimalist POS
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1b1b1b'
  on-surface-variant: '#4c4546'
  inverse-surface: '#303030'
  inverse-on-surface: '#f1f1f1'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#5d5f5f'
  on-secondary: '#ffffff'
  secondary-container: '#dfe0e0'
  on-secondary-container: '#616363'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1b1b1b'
  on-tertiary-container: '#848484'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c7'
  on-secondary-fixed: '#1a1c1c'
  on-secondary-fixed-variant: '#454747'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c6'
  on-tertiary-fixed: '#1b1b1b'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1b1b1b'
  surface-variant: '#e2e2e2'
typography:
  display:
    fontFamily: Space Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.2'
  body-lg:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '500'
    lineHeight: '1.5'
  body-sm:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.5'
  label-bold:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1'
    letterSpacing: 0.05em
  price-display:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1'
    letterSpacing: -0.02em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit: 8px
  container-padding: 24px
  gutter: 16px
  touch-target-min: 48px
  element-gap: 12px
---

## Brand & Style

The design system is anchored in extreme clarity and fluid geometry. It recontextualizes the utilitarian environment of a supermarket through a lens of high-fashion minimalism. By stripping away all color and traditional "functional" clutter, it creates a focused, high-contrast workspace that reduces cognitive load for the cashier while providing a premium, modern experience for the customer.

The visual style merges **Minimalism** with **Organic Curves**. It rejects the harsh right angles typically found in enterprise software, opting instead for pill shapes, perfect circles, and hyper-rounded containers. This softness balances the aggressive high contrast of the black-and-white palette, making the interface feel approachable yet sophisticated.

## Colors

This design system utilizes a strict binary palette. There are no shades of gray. Contrast is achieved solely through the inversion of black and white.

- **Primary (Action):** Pure Black (#000000) is used for primary actions, heavy typography, and structural boundaries.
- **Secondary (Inversion):** Pure White (#FFFFFF) is used for text on black backgrounds and as the main workspace surface.
- **Functional Logic:** Errors or alerts are communicated via thick black borders or inverted "Negative" states rather than red or yellow. Focus states use a heavy 3px or 4px black stroke.

## Typography

The design system uses **Space Grotesk** exclusively. Its geometric construction and idiosyncratic "tech" terminals complement the circular UI elements. 

To maintain hierarchy without color, we rely on extreme weight variance and scale. Headlines are set to Bold or SemiBold with tight letter spacing for a punchy, editorial look. Labels utilize uppercase styling and tracking to differentiate them from body text. In the context of a cashier app, price displays are treated as primary "Display" elements to ensure legibility from a distance.

## Layout & Spacing

The layout follows a **fluid grid** model optimized for landscape tablet orientations. The interface is divided into two primary zones: the "Basket" (33% width) and the "Catalog/Keypad" (66% width).

The rhythm is dictated by an 8px square grid. Large "safe areas" are maintained around touch targets to prevent mis-taps in high-speed environments. Whitespace is used aggressively; components are never crowded. Every grouped set of elements is housed within a container featuring high-padding and organic curves to maintain the soft, modern vibe.

## Elevation & Depth

This system rejects shadows and blurs entirely. Depth is achieved through **Bold Borders** and **Tonal Inversion**. 

- **Level 0 (Base):** White background.
- **Level 1 (Containers):** Elements are defined by a 2px solid black border.
- **Level 2 (Active/Floating):** Elements are solid black with white text. 

To simulate stacking, we use "Offset Borders" where a container has a thick black stroke, and the element beneath it is offset by 4px or 8px, creating a pseudo-3D effect without the use of gradients or shadows.

## Shapes

The shape language is the core differentiator of the design system. It utilizes **Pill-shaped (3)** geometry for almost all interactive components.

- **Buttons:** Perfectly circular for icons or pill-shaped for text.
- **Containers:** Corner radii start at 24px and increase for larger panels, ensuring they feel "organic" rather than mechanical.
- **The "Curve Rule":** Whenever two lines meet, they should ideally be joined by a significant radius. Sharp 90-degree angles are forbidden, as the goal is to make the software feel as fluid as the movement of items over a scanner.

## Components

### Buttons
Primary buttons are solid black with white text, using a full pill-radius. Secondary buttons use a 2px black stroke with white fill. "Ghost" buttons for minor actions use bold underlined text.

### Product Chips
Used for quick-add categories. These are large, pill-shaped buttons with 18px bold text. They should have enough height (min 64px) to be hit easily during a fast checkout.

### The Checkout List (Basket)
Items in the basket are separated by wide gaps rather than thin lines. Each item entry is a rounded-rectangle card. Quantity selectors are perfect circles with "+" and "-" icons.

### Keypad
The numeric keypad for manual SKU entry consists of perfect circles. The "Enter/Pay" button is an oversized pill-shape that spans the width of the keypad, finished in solid black.

### Input Fields
Inputs are pill-shaped with a 2px black border. When focused, the border thickness increases to 4px. Placeholder text is the only instance where a 50% black "stipple" or high-contrast pattern can be used to simulate a lighter tone without using actual gray.

### Additional Components
- **Scanner Feedback:** A large, circular pop-up overlay that appears for 500ms when an item is successfully scanned, containing a giant checkmark.
- **Tote Indicators:** Circular badges with numbers used to indicate which bag an item belongs to.