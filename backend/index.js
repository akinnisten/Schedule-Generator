const express = require("express");
const cors = require("cors");
const app = express();
const PORT = 5001; 

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => res.send("Backend running!"));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://localhost:${PORT}`);
});