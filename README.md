<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->

<img align="right" width="300" src="res/logo.png" />

# Wizgoose

Wizgoose is a library that adds replication and change tracking to Luau tables through metatable magic. Said magical objects have `Value` property which knows when its changed, what changed, and how it changed, thus allowing it to signal changes, such as when property changes, or when an array has an item added into it or removed from, this applies both to server and client.
