import 'package:flutter/material.dart';
import 'product.dart';
//import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference productsRef = FirebaseFirestore.instance.collection(
    'products',
  );

  List<Product> products = [];

  String _searchQuery = "";
  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) {
      return products;
    } else {
      return products
          .where(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
  }

  void addProduct(String name, double price) async {
    await productsRef.add({'name': name, 'price': price});
  }

  void showAddProductDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Product"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Product Name"),
              ),

              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                String name = nameController.text;
                double price = double.parse(priceController.text);

                addProduct(name, price); // ✅ This handles adding + saving

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void showEditPriceDialog(String docId, String name, double price) {
    TextEditingController priceController = TextEditingController(
      text: price.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Price - $name"),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "New Price"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                double newPrice = double.parse(priceController.text);
                await productsRef.doc(docId).update({'price': newPrice});
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void showProductOptionsDialog(String docId, String name, double price) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: const Text("Choose an action"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showEditPriceDialog(docId, name, price);
              },
              child: const Text("Edit Price"),
            ),
            TextButton(
              onPressed: () async {
                await productsRef.doc(docId).delete(); // delete sa Firestore
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _sortOption = 'name';

  void _sortProducts() {
    if (_sortOption == 'name') {
      products.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortOption == 'price') {
      products.sort((a, b) => a.price.compareTo(b.price));
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mardelyn Price List",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 46, 133, 255),
                Color.fromARGB(255, 107, 188, 255),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // ✅ Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                filled: true,
                fillColor: Colors.grey[100],
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
            ),
          ),

          // ✅ Sort Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Sort by:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _sortOption,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'price', child: Text('Price')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value!;
                      _sortProducts();
                    });
                  },
                ),
              ],
            ),
          ),

          // ✅ Product list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productsRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;

                // 🔹 Apply search filter
                final filteredDocs = allDocs.where((doc) {
                  final name = doc['name'] as String;
                  return name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
                }).toList();

                // 🔹 Apply sort
                filteredDocs.sort((a, b) {
                  if (_sortOption == 'name') {
                    return (a['name'] as String).compareTo(b['name'] as String);
                  } else if (_sortOption == 'price') {
                    return (a['price'] as num).compareTo(b['price'] as num);
                  }
                  return 0;
                });

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("No products found"));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final name = doc['name'];
                    final price = doc['price'];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          "₱$price",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: price > 100 ? Colors.red : Colors.green,
                          ),
                        ),
                        onLongPress: () {
                          showProductOptionsDialog(doc.id, name, price);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddProductDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Product"),
      ),
    );
  }
}
