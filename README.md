# record_processor

Script to parse a custom protocol format (MPS7) and answer some questions about the data provided.

### Usage

```bash
$ cd <project_directory>
$ record_processor.rb <data_file>
```

Examples:

```bash
$ cd /User/bryon.wicklund/projects/record_processor/
$ record_processor.rb data.dat
```

### Currently supported functionality

Reads data in following format:

Header:
```
| 4 byte magic string "MPS7" | 1 byte version | 4 byte (uint32) # of records |
```

Row:
```
| 1 byte record type enum | 4 byte (uint32) Unix timestamp | 8 byte (uint64) user ID | 8 byte (float64) (if enum is 0 || 1)
```

***NOTE: Since doing math on floats, especially when dealing with a base10 currency number is not always accurate we are converting the 8byte (float64) from a `Float` to `BigDecimal` type***

Crude Validations:

Program will `exit` if it does not detect the "magic string": 'MPS7'

Program will `warn` if total records does not match the record count in header

Program will `exit` if epoch time provided is not a integer

Program will `exit` if user ID is not a valid unsigned 8byte Int

Program will `exit` if dollar amount is not a valid float

Program will `exit` if record type is not in the follow list:
```
0x00: Debit
0x01: Credit
0x02: StartAutopay
0x03: EndAutopay
```


#### Header Row `unpack`
```
a4CN

a4 = 4 byte arbitrary binary string
C = unsigned 8-bit(integer)
N = 32-bit unsigned, network (big-endian) byte order
```
#### Data Row `unpack`

```
CNQ>G

C = unsigned 8-bit(integer)
N = 32-bit unsigned, network (big-endian) byte order
Q> = 64-bit unsigned, big-endian (uint64_t)
G (optionally) = double-precision, network (big-endian) byte order (If enum is 0 or 1)
```

#### Results on data set given in `data.dat`
```
WARNING: Records count does not match header value: Records: 72 Header: 71

Header Row Record Count: 71
Total Records: 72
Total Credits: $10073.359933036814
Total Debits: $18203.6995334020799
Total Autopays Started: 10
Total Autopays Ended: 8
Balance for user ID 2456938384156277127: $0.0
```

