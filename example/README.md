# command_chain_timeline example

The example follows one realistic online-store session:

1. Restore a customer session and open a product.
2. Load product details and recommendations in parallel.
3. Queue cart updates.
4. Record an expired promo code and complete checkout successfully.
5. Export a schema-versioned JSON document.
6. Paste JSON or open a JSON file on desktop and web.
7. Decode the JSON before opening an English `CommandChainTimeline`.

File selection intentionally stays in the example application. The timeline
package only renders the supplied snapshot.
