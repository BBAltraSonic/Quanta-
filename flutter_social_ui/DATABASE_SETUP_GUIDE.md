# 🗄️ **Database Setup Guide - Fix Mock Data Issue**

## 🚨 **The Problem**

Your app is using mock data because the **Supabase database tables don't exist**. The app connects to Supabase successfully, but when it tries to query tables like `post_likes` and `saved_posts`, they don't exist, so the app falls back to demo data.

## ✅ **The Solution**

You need to run the database schema to create all the required tables.

---

## 🛠️ **Step 1: Access Supabase Dashboard**

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in to your account
3. Select your project: **neyfqiauyxfurfhdtrug** (from your app config)

---

## 🛠️ **Step 2: Run the Database Schema**

### **Option A: Using Supabase Dashboard (Recommended)**

1. In your Supabase dashboard, go to **SQL Editor**
2. Copy the entire contents of `supabase_schema.sql` from your project root
3. Paste it into the SQL Editor
4. Click **Run** to execute the schema

### **Option B: Using Supabase CLI (Advanced)**

```bash
# Install Supabase CLI if you haven't
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref neyfqiauyxfurfhdtrug

# Run the schema
supabase db push
```

---

## 🛠️ **Step 3: Verify Tables Were Created**

After running the schema, verify these tables exist in your database:

### **Core Tables:**
- ✅ `users`
- ✅ `avatars` 
- ✅ `posts`
- ✅ `comments`
- ✅ `chat_sessions`
- ✅ `chat_messages`
- ✅ `follows`

### **Interaction Tables (These were missing!):**
- ✅ `post_likes` 
- ✅ `saved_posts`
- ✅ `post_shares`

### **Storage Buckets:**
- ✅ `avatars` bucket
- ✅ `posts` bucket

---

## 🛠️ **Step 4: Test the Fix**

1. **Stop your Flutter app** (press `q` in the terminal)
2. **Restart the app**:
   ```bash
   flutter run -d emulator-5554
   ```
3. **Check the logs** - you should no longer see these errors:
   ```
   ❌ Failed to check like status: relation "public.post_likes" does not exist
   ❌ Failed to check save status: relation "public.saved_posts" does not exist
   ```

---

## 🎯 **Expected Results**

After setting up the database:

### **✅ What Will Work:**
- **Real social interactions** (likes, saves, shares)
- **Real content persistence** (posts saved to database)
- **Real user authentication** (users stored in database)
- **Real chat sessions** (conversations saved)
- **Real follower relationships**

### **⚠️ What Will Still Use Mock Data:**
- **Content feed** (until you create real posts)
- **AI chat responses** (placeholder HuggingFace API key)
- **Search results** (until real content exists)

---

## 🔧 **Troubleshooting**

### **If you get permission errors:**
1. Make sure you're signed in to the correct Supabase account
2. Verify you have admin access to the project
3. Check that the project ID matches: `neyfqiauyxfurfhdtrug`

### **If tables already exist:**
The schema uses `CREATE TABLE` statements. If tables exist, you might get errors. You can:
1. **Drop existing tables first** (⚠️ **This will delete data!**)
2. **Or modify the schema** to use `CREATE TABLE IF NOT EXISTS`

### **If you still see mock data:**
1. **Check the Flutter console** for database connection errors
2. **Verify your Supabase URL and key** in `lib/config/app_config.dart`
3. **Make sure Row Level Security policies** are properly configured

---

## 📊 **Database Schema Overview**

The schema creates:

- **8 core tables** for users, avatars, posts, comments, chats, follows, likes, saves
- **19 indexes** for performance
- **Row Level Security policies** for data protection  
- **Triggers** for automatic counter updates
- **Storage buckets** for media files
- **Functions** for maintaining data consistency

---

## 🚀 **Next Steps After Database Setup**

1. **Create real avatars** using the avatar creation wizard
2. **Upload real content** using the content upload screen
3. **Test social interactions** (likes, saves, follows)
4. **Configure AI services** (fix HuggingFace API key)
5. **Add real users** through the authentication system

---

## 💡 **Pro Tips**

- **Backup your database** before making changes
- **Test in development** before applying to production
- **Monitor the Supabase dashboard** for query performance
- **Use the SQL Editor** to inspect data and debug issues
- **Enable database logs** to troubleshoot connection problems

---

**Once you run this database schema, your app will switch from mock data to real backend operations!** 🎉
