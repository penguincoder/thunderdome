# Welcome to the ThunderDome

This is an administrative panel for Rails styled models. In a nutshell, this application shows you a bunch of models in a list and lets you perform basic filtering, paginated displays and the usual edit/update/destroy functions.

The ThunderDome is released under the MIT license. See the `LICENSE` file for the complete text.

## Requirements

* Ruby
* Sinatra
* HAML
* Web browser with or without JavaScript support

## Paginated Viewing

All models get paginated views. 100 records per-page. Filtering is available.  It's all basic, but it really gets the job done and gets out of your way.

Sorting, by default, is `id ASC`. If you would like to change it, add a class method called `custom_order` that returns a string of the order you would like to use.

## Creation And Editing

The ThunderDome will introspect all of the objects and infer what needs to be done on each model and build a form with all of the attributes listed in alphabetical order. If a column is a boolean, it displays a checkbox, strings get a text field and texts get a text area. Parent model relationships (yes, it does those!) get a select.

## Has-Many / Belongs-To's

It will handle parent-child relationships. In the child paginated views, it will display the parent's ID as an integer, but it's an abbreviation and as long as your model responds to `to_s` it will put that into the full definition in the `<abbr>` tag. In the edit view, it will provide a `<select>` list of models you can pick from. To facilitate this, you must provide a `for_select` class method. It's pretty simple, here is an example of one:

    class Agency < ActiveRecord::Base
      def self.for_select
        all(:order => 'name ASC').collect do |a|
          [ a.name, a.id.to_s ]
        end
      end
      def self.custom_order
        'agencies.code ASC'
      end
    end

It is important to note that i called `to_s` on the integer `id`. Trust me, this works and without the conversion it will not remember to pre-select values.

## Has And Belongs To Many

I will get back to you on this one.

## How does this really work? Really.

You `require` the appropriate files and populate a variable with a list of the models you want, i do the rest. Filtering requires you to add the column names of the columns you want filtered in a different variable.

The trickiest (and only) part of running this is you to appropriately load all of your files in the `one_man.rb` file. I have included a sample.

This application is less than 400 lines, so once you add it, it is unlikely to need to be changed or updated. It depends on nothing in your models and infers everything it needs to operate.

## How do i use this?

You can do with it as you need to, but i have a copy of this inside of my `RAILS_ROOT` directory in a directory called thunderdome. From there, you just configure your `one_man.rb` and your `config/database.yml` file. I will assume you know how to configure your database if you are this far into the game. Here is an example of a `one_man.rb` file that might be useful to some people. For this, i am going to examine NewEgg. Please note that i have never worked on anything for NewEgg. I have no idea what it is actually like. I am going to describe what i think the application structure might be like if it were written in Ruby, which it's not.

    # avoid repetition, cache this value
    model_dir = File.join(File.dirname(__FILE__), '..', 'app', 'models')
    
    # the main menu is stored the model ProductCategory. It has children
    # (submenu) and the parents (ProductCategory models with no parent) are the
    # topmost. an example would be like 'COMPUTER HARDWARE' and 'NETWORKING'.
    require File.join(model_dir, 'product_category')
    
    # list of manufacturers, for any product.
    require File.join(model_dir, 'product_manufacturer')
    
    # for role based access control, you control the permissions here, but
    # you configure the roles in the master application and which users belong
    # to which roles
    require File.join(model_dir, 'permission')
    
    # the actual products you see on the page
    require File.join(model_dir, 'product')
    
    # set up your variables all nicely so the app runs with your codes
    @@constants = %w(product_category product_manufacturer permission product)
    @@sortable_columns = %w(name controller action)

What all of that means is this:

1. You used `require` to load the models into Ruby.
2. You told the `@@constants` variable what the symbolized name of those models are. If that variable does not contain your model, you cannot view it in the application. An exception will be thrown.
3. Any table that has a `name`, `controller`, or `action` column will be filtered on those columns. Watch out and have your indexes ready.
4. On the home page for ThunderDome it will have four entries, alphabetized.

## To Run

It's pretty easy once you configure your initialization file:

    userbob@myhost> ruby thunderdome.rb

## What about REST?

I'll get back to you on this one when it matters for this type of thing.

