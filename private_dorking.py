import requests
from bs4 import BeautifulSoup as bs
from re import findall as reg
from datetime import datetime, timedelta
import os
from colorama import init, Fore, Style
from selenium import webdriver
from bs4 import BeautifulSoup as bs
from user_agent import generate_user_agent
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from tabulate import tabulate
from urllib.parse import parse_qs, urlparse

init(autoreset=True)

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'}
now = datetime.now()
def center_text(text, color=Fore.WHITE):
    terminal_width = os.get_terminal_size().columns
    return color + text.center(terminal_width) + Style.RESET_ALL
def logo1():
    print(center_text("💻 Private Dorking 💻"))
    print(center_text("===============TG:https://t.me/warrio4 ==============="))
def logo():
    l = '''
:::::::::: :::     ::: ::::::::::: :::        :::::::::   ::::::::  :::::::::  :::    ::: :::::::::: :::::::::  
:+:        :+:     :+:     :+:     :+:        :+:    :+: :+:    :+: :+:    :+: :+:   :+:  :+:        :+:    :+: 
+:+        +:+     +:+     +:+     +:+        +:+    +:+ +:+    +:+ +:+    +:+ +:+  +:+   +:+        +:+    +:+ 
+#++:++#   +#+     +:+     +#+     +#+        +#+    +:+ +#+    +:+ +#++:++#:  +#++:++    +#++:++#   +#++:++#:  
+#+         +#+   +#+      +#+     +#+        +#+    +#+ +#+    +#+ +#+    +#+ +#+  +#+   +#+        +#+    +#+ 
#+#          #+#+#+#       #+#     #+#        #+#    #+# #+#    #+# #+#    #+# #+#   #+#  #+#        #+#    #+# 
##########     ###     ########### ########## #########   ########  ###    ### ###    ### ########## ###    ### 
'''
    print(center_text(l))
def SV(data, filename):
    with open(filename, 'a') as f:
        f.write(data + '\n')
def zoneh():
    print(center_text("ZONE-H function selected.",Fore.GREEN))
    driver = webdriver.Firefox()
    driver.get("https://zone-h.org/")
    ZHE = driver.get_cookie("ZHE")['value']
    PHPSESSID = driver.get_cookie("PHPSESSID")['value']

    cookies = {'ZHE': ZHE, 'PHPSESSID': PHPSESSID}
    
    for param in ['archive', 'archive/published=0']:
        page = 0
        while True:
            page += 1
            url = f'https://zone-h.org/{param}/page={page}'
            r = requests.get(url, headers=headers, cookies=cookies).text
            r = r.replace('\n', '').replace(' ', '').replace('\t', '')
            if 'inputtype="text"name="captcha"value=""' in r:
                driver.get(url)
                page -=1
                print(f'CAPTCHA detected! Please open http://www.zone-h.com/{param} and solve the CAPTCHA.')
                input('Press Enter to Continue after solving the CAPTCHA...')
                continue
            else:
                sites = reg('"></td><td></td><td>(.*?)</td><td>', r)
                sites = [s for s in sites if '...' not in s and '....' not in s and '..' not in s]
                sites = [*set(sites)]
                if str(sites) == '[]':
                    break
                else:
                    for site in sites:
                        SV(site, 'sites.txt')

def cleaner_site(site):
    if '/' in str(site):site = str(site).split('/',1);site = str(site[0])
    site = str(site).replace('www.','')
    return site

def zone_xsec():
    print(center_text("ZONE-XSEC function selected.",Fore.GREEN))
    page = 1
    while True:
        url = 'https://zone-xsec.com/archive/page={}'.format(page)
        r = requests.get(url , headers=headers).text
        r = bs(r , 'html.parser')
        body = r.find('tbody')
        body = str(body).replace('\n','')
        sites = reg('/></td><td></td><td>(.*?)</td><td><a href',str(body))
        if sites == []:
            break
        sites = [cleaner_site(sites) for sites in sites]
        sites = [sites for sites in sites if '..' not in str(sites) and '...' not in str(sites) and '....' not in str(sites)]
        sites = [*set(sites)]
        for site in sites:
            site = root_domain(site)
            SV(site,'sites.txt')
        page +=1
    
    return
def root_domain(url):
    if 'http://' not in str(url) and 'https://' not in str(url):
        url = 'http://' + str(url)
    return str(urlparse(url).netloc).replace('www.','')

def haxor():
    print(center_text("Haxor function selected.",Fore.GREEN))
    page = 1
    while True:
        url = f'https://haxor.id/archive?page={page}'
        r = requests.get(url, headers=headers).text
        if 'only 50 page newest are allowed to be shown to public' in r:
            break
        r = bs(r, 'html.parser')
        sites = r.find_all('tbody')
        for i in sites:
            if '_blank' in str(i):
                sites = str(i)
        qsdhgaç_ = reg('href="(.*?)"', str(sites))
        qsdhgaç_ = [q for q in qsdhgaç_ if q.startswith('http')]
        qsdhgaç_ = [q.replace('http://', '').replace('https://', '').split('/')[0].replace('www.', '') for q in qsdhgaç_]
        print(f'\n[Page {page}] {url}\n')
        for i in qsdhgaç_:
            SV(i, 'sites.txt')
        page += 1

def hypestat():
    print(center_text("Hypestat function selected.",Fore.GREEN))
    page = 0
    while True:
        page += 1
        url = f'https://hypestat.com/recently-updated/{page}'
        r = requests.get(url, headers=headers).text
        dates = reg('<dd>(.*?)<br>', str(r))
        r = bs(r, 'html.parser')
        links = r.find_all('a', href=True)
        links = [str(link).split('https://hypestat.com/info/')[1].split('">')[0] for link in links if 'https://hypestat.com/info/' in str(link)]
        links = [*set(links)]
        for i in range(len(links)):
            try:
                if 'day' in str(dates[i]).lower():
                    break
            except:
                continue
            SV(links[i], 'sites.txt')

def grabbercubdomain(yesterday, date):
    print(center_text("CubDomain function selected.",Fore.GREEN))
    page = 1
    while True:
        url = f'https://www.cubdomain.com/domains-registered-by-date/{date}/{page}'
        req = requests.get(url, headers=headers).text
        req = bs(req, 'html.parser')
        req = req.find_all('main')
        sites = reg('href="https://www.cubdomain.com/site/(.*?)"', str(req))
        if str(page) == '1' and not sites:
            print(f'\n[INFO] List is Not Available for {date}')
            new = yesterday - timedelta(days=1)
            inputDate = new.strftime('20%y-%m-%d')
            grabbercubdomain(new, inputDate)
            break
        sites = [*set(sites)]
        for i in sites:
            SV(i, 'sites.txt')
        if not sites:
            break
        page += 1

def cubdomainmain():
    yesterday = now.date() - timedelta(days=1)
    inputDate = yesterday.strftime('%d-%m-20%y')
    day, month, year = inputDate.split('-')
    isValidDate = True
    try:
        datetime(int(year), int(month), int(day))
    except ValueError:
        isValidDate = False
    if isValidDate:
        date = f'{year}-{month}-{day}'
        grabbercubdomain(yesterday, date)
    else:
        cubdomainmain()

def main():
    logo()
    logo1()
    while True:
        print("\n" + center_text("API Menu"))
        print(center_text("1. Haxor"))
        print(center_text("2. Hypestat"))
        print(center_text("3. CubDomain"))
        print(center_text("4. Zone-H"))
        print(center_text("5. Zone-XSEC"))
        print(center_text("6. Exit"))

        choice = input(center_text("Select an option: "))

        if choice == '1':
            haxor()
        elif choice == '2':
            hypestat()
        elif choice == '3':
            cubdomainmain()
        elif choice == '4':
            zoneh()
        elif choice == '5':
            zone_xsec()        
        elif choice == '6':
            print("Exiting... Enjoy @warrio4")
            break
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    
    main()
