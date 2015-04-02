import csv

#  Creating new .csv files 
newfile1 = open ('s_flits_in_new.csv',"w+")
newfile2 = open ('s_flits_out_new.csv',"w+")

#  Reading file one and eliminating x,z and zero source and dest rows
with open ('s_flits_in.csv') as csvfile:
    readcsv = csv.reader(csvfile, delimiter=',')
    writer = csv.writer(newfile1,delimiter=',')
    for row in readcsv:
        if ('xxxx' in row) or ('zzzz' in row) or (('0' in row[4]) and ('0' in row[5])):
            print(row)
        else:
             writer.writerow(row)

#  Reading file two and eliminating x,z and zero source and dest rows
with open ('s_flits_out.csv') as csvfile:
    readcsv = csv.reader(csvfile, delimiter=',')
    writer = csv.writer(newfile2,delimiter=',')
    for row in readcsv:
        if ('xxxx' in row) or ('zzzz' in row) or (('0' in row[4]) and ('0' in row[5])):
            print(row)
        else:
             writer.writerow(row)

# Closing both new created .csv files
newfile1.close()
newfile2.close()                    
       

