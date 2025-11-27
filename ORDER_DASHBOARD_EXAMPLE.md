# Order Dashboard Example Design

## Visual Layout Example

```
┌─────────────────────────────────────────────────────────┐
│  My Orders                                    [Search]   │
├─────────────────────────────────────────────────────────┤
│  [All] [To Pay] [To Install] [To Receive] [To Rate]   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Order #ABC12345                    [Status Badge]│  │
│  │ ┌────────┐  Sliding Window - Clear Glass        │  │
│  │ │ [IMG]  │  Dimensions: 60" × 70"                │  │
│  │ │        │  Glass: Clear Glass                   │  │
│  │ │        │  Frame: Silver Anodized               │  │
│  │ └────────┘  ₱15,000.00                           │  │
│  │                                                      │
│  │  Status: To Pay                                    │
│  │  Order Date: 15/01/2024                            │
│  │                                                      │
│  │  [View Details]  [Pay Now]                         │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Order #DEF67890                    [Status Badge]│  │
│  │ ┌────────┐  Sliding Door - Tempered Glass         │  │
│  │ │ [IMG]  │  Dimensions: 80" × 70"                 │  │
│  │ │        │  Glass: Tempered Glass                 │  │
│  │ │        │  Frame: Black Powder-Coated            │  │
│  │ └────────┘  ₱25,000.00                            │  │
│  │                                                      │
│  │  Status: To Install                                │
│  │  Order Date: 10/01/2024                            │
│  │                                                      │
│  │  [View Details]  [Track Order]                    │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Key Features to Implement

1. **Order Card Design**
   - Product image thumbnail
   - Order number
   - Product name and specifications
   - Dimensions, Glass type, Frame type
   - Total price
   - Status badge with color coding
   - Order date
   - Action buttons based on status

2. **Status Badges**
   - To Pay: Orange badge
   - To Install: Blue badge
   - To Receive: Purple badge
   - To Rate: Green badge
   - Completed: Dark green badge

3. **Action Buttons**
   - To Pay: "Pay Now" button
   - To Install: "Track Order" button
   - To Receive: "Track Order" button
   - To Rate: "Rate & Review" button

4. **Order Details**
   - Expandable order card
   - Full product information
   - Material breakdown
   - Installation details
   - Payment information

