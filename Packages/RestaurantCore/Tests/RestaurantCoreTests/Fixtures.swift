import Foundation
import FoodCore
@testable import RestaurantCore

/// FICTIONAL restaurants and numbers, written for these tests. No real chain's menu or nutrition is used anywhere
/// in this package; real data must come from the chains themselves or from a licensed source, with provenance.
enum Fixtures {
    static let menuCSV = """
    restaurant,restaurant_category,region,section,item,variant,serving,serving_g,calories,protein_g,carbs_g,fat_g,sat_fat_g,fiber_g,sugars_g,sodium_mg,allergens,diet_tags,modifier_groups,aliases,source_kind,source_name,license,as_of
    Burger Barn,burgers,US,Burgers,Classic Barn Burger,,1 burger,220,540,28,40,29,11,2,9,1050,milk;wheat;egg,,Burger Toppings;Burger Sauce,barn burger;classic,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Burgers,Double Barn Burger,,1 burger,310,780,49,41,46,19,2,9,1400,milk;wheat;egg,,Burger Toppings;Burger Sauce,dbl barn,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Burgers,Garden Veggie Burger,,1 burger,240,460,20,52,18,3,6,8,880,wheat;soy,vegetarian,Burger Toppings,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Chicken,Crispy Chicken Sandwich,,1 sandwich,230,590,30,52,28,5,3,7,1190,wheat;egg;milk,,Burger Sauce,chix sandwich,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Sides,Fries,Small,small,71,230,3,30,11,2,3,0,160,,vegan,,french fries;chips,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Sides,Fries,Medium,medium,111,340,4,45,16,3,4,0,230,,vegan,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Sides,Fries,Large,large,150,450,6,60,21,4,5,0,310,,vegan,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Sides,Side Salad,,1 salad,130,70,3,8,3,1,3,4,95,,vegetarian,,garden salad,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Drinks,Cola,Small,16 fl oz,,150,0,39,0,0,0,39,15,,vegan,,soda;pop,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Drinks,Cola,Large,32 fl oz,,290,0,78,0,0,0,78,30,,vegan,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Burger Barn,burgers,US,Drinks,Chocolate Shake,,16 fl oz,,620,14,85,24,15,1,74,380,milk,vegetarian,,milkshake,demoFictional,Helios fictional demo menus,cc0,2026-10
    Taco Tangent,mexican,US,Tacos,Grilled Chicken Taco,,1 taco,105,180,14,18,6,2,2,1,380,wheat;milk,,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Taco Tangent,mexican,US,Tacos,Carne Asada Taco,,1 taco,110,210,11,19,10,3,2,1,420,wheat,,,steak taco,demoFictional,Helios fictional demo menus,cc0,2026-10
    Taco Tangent,mexican,US,Tacos,Veggie Taco,,1 taco,120,150,5,22,5,1,4,2,310,wheat,vegan,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Taco Tangent,mexican,US,Bowls,Burrito Bowl,,1 bowl,430,650,38,72,22,7,11,6,1340,milk,,Bowl Protein,burrito bol,demoFictional,Helios fictional demo menus,cc0,2026-10
    Taco Tangent,mexican,US,Sides,Chips and Guac,,1 order,150,520,6,52,32,5,8,2,430,,vegan,,chips & guacamole,demoFictional,Helios fictional demo menus,cc0,2026-10
    Bean There Coffee,coffee,US,Drinks,Latte,Short,8 fl oz,,100,6,9,4,2,0,9,85,milk,vegetarian,Milk,cafe latte,demoFictional,Helios fictional demo menus,cc0,2026-10
    Bean There Coffee,coffee,US,Drinks,Latte,Tall,12 fl oz,,150,9,13,6,3,0,13,125,milk,vegetarian,Milk,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Bean There Coffee,coffee,US,Drinks,Latte,Grande,16 fl oz,,190,12,18,7,4,0,17,160,milk,vegetarian,Milk,,demoFictional,Helios fictional demo menus,cc0,2026-10
    Bean There Coffee,coffee,US,Bakery,Blueberry Muffin,,1 muffin,130,420,6,60,17,3,1,33,380,wheat;egg;milk,vegetarian,,,demoFictional,Helios fictional demo menus,cc0,2026-10
    """

    static let modifiersCSV = """
    restaurant,group,option,rule,default,calories,protein_g,carbs_g,fat_g,sodium_mg
    Burger Barn,Burger Toppings,Cheese,multiple,yes,80,5,1,6,300
    Burger Barn,Burger Toppings,Lettuce and Tomato,multiple,yes,5,0,1,0,2
    Burger Barn,Burger Toppings,Bacon,multiple,no,70,5,0,5,260
    Burger Barn,Burger Toppings,Fried Egg,multiple,no,90,6,0,7,95
    Burger Barn,Burger Sauce,Barn Sauce,single,yes,110,0,2,12,180
    Burger Barn,Burger Sauce,Mustard,single,no,5,0,1,0,55
    Taco Tangent,Bowl Protein,Chicken,single_required,yes,160,28,0,5,420
    Taco Tangent,Bowl Protein,Steak,single_required,no,190,24,0,10,480
    Taco Tangent,Bowl Protein,Tofu,single_required,no,130,14,3,7,300
    Bean There Coffee,Milk,2% Milk,single_required,yes,60,4,6,2,50
    Bean There Coffee,Milk,Nonfat Milk,single_required,no,40,4,6,0,50
    Bean There Coffee,Milk,Whole Milk,single_required,no,80,4,6,4,50
    Bean There Coffee,Milk,Oat Milk,single_required,no,70,1,10,3,60
    """

    static func library() -> RestaurantLibrary {
        let report = LibraryImporter.importMenu(csv: menuCSV, modifiersCSV: modifiersCSV)
        precondition(!report.hasErrors, "fixture must import cleanly: \(report.issues)")
        return RestaurantLibrary(version: "test-1", restaurants: report.restaurants)
    }
}
