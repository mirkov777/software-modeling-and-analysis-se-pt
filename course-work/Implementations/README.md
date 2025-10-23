# Reddit – Курсов проект

**Факултетен номер:** 2301322021
**Тема:** Reddit – модел на база данни и Data Warehouse  

## 📘 Описание
Проектът представя опростен модел на платформата Reddit.  
Включва:
- Концептуален модел (Chen’s notation)  
- Логически модел (Crow’s Foot)  
- SQL скриптове за създаване и зареждане на база данни  
- Примерен Data Warehouse (DW) модел и скрипт за трансфер на данни  
- Power BI визуализация за анализ на данните  

## 📂 Съдържание
- **Reddit_chens.drawio** – концептуален модел (Chen)  
- **reddit_crows.png** – логически модел (Crow’s Foot)  
- **RedditDB.sql** – създава основната база данни (OLTP)
- **RedditDB_generate_entries.sql** – попълва базата с примерни данни  
- **RedditDB_DW.sql** – създава структурата на Data Warehouse  
- **dw_fill_from_real.sql** – извлича данни от OLTP базата и ги вкарва в DW  
- **reddit_stats.pbix** – Power BI файл с визуализации върху DW  

## ⚙️ Инструкции за стартиране

1. **Импортирай SQL файловете в Microsoft SQL Server Management Studio (SSMS):**
   - Първо стартирай `RedditDB.sql`  
   - После стартирай `RedditDB_generate_entries.sql`, за да добавиш примерни записи  

2. **Създай и зареди Data Warehouse:**
   - Стартирай `RedditDB_DW.sql`  
   - Стартирай `dw_fill_from_real.sql`, за да прехвърлиш данните от основната база  

3. **Визуализация:**
   - Отвори файла `reddit_stats.pbix` в **Power BI Desktop**  
   - Обнови източниците на данни, ако е необходимо (ако базата ти е на различен сървър или инстанция)  

## 🧩 Забележки
- Проектът е тестван на **Microsoft SQL Server**.  
- Ако Power BI не се свързва автоматично, в настройките посочи правилния сървър и база данни.  
- Всички модели могат да бъдат отворени чрез **draw.io** и **Power BI Desktop**. 